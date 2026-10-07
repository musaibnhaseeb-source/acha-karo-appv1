import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'package:acha_karo/state/deed_queue.dart';
import 'package:acha_karo/state/home_cache.dart';
import 'package:acha_karo/state/home_data.dart';
import 'package:acha_karo/state/app_state.dart';
import 'package:acha_karo/utils/deed_photo_upload.dart';

// Offline deed queue (layer 2): never lose a deed, never send one twice, survive a kill at any
// step, and leave nothing behind on sign-out. A fake server stands in for Supabase; "killing the
// app" = dropping the DeedQueue object and building a new one from the same folder.

const uid = 'user-a';

class FakeServer {
  final Set<String> objects = {};
  final List<Map<String, String?>> deeds = [];
  int afterInsertCalls = 0;
  bool offline = false;
  // Server did the work but the answer never reached the phone.
  bool loseNextUploadAnswer = false;
  bool loseNextInsertAnswer = false;
  // The app is killed right after the server saved the deed (non-network exception).
  bool killAfterNextInsert = false;
  bool deedCheckOffline = false;

  void _net() {
    if (offline) throw const SocketException('Failed host lookup');
  }

  Future<void> upload(String path, Uint8List bytes) async {
    _net();
    if (objects.contains(path)) throw const StorageException('The resource already exists', statusCode: '409', error: 'Duplicate');
    objects.add(path);
    if (loseNextUploadAnswer) {
      loseNextUploadAnswer = false;
      throw const StorageException('Connection closed', statusCode: 'ClientException');
    }
  }

  Future<bool> deedUsesPhoto(String path) async {
    if (deedCheckOffline) throw const SocketException('Network is unreachable');
    _net();
    return deeds.any((d) => d['photo_url'] == path);
  }
}

class FakeOps implements DeedSendOps {
  final FakeServer s;
  FakeOps(this.s);

  @override
  Future<PhotoUploadResult> uploadPhoto(String path, Uint8List bytes) => uploadPreparedDeedPhoto(path, bytes, upload: s.upload, deedUsesPhoto: s.deedUsesPhoto);

  @override
  Future<({String id, String status})?> findDeedByPhoto(String photoPath) async {
    s._net();
    final hit = s.deeds.where((d) => d['photo_url'] == photoPath);
    return hit.isEmpty ? null : (id: hit.first['id']!, status: hit.first['status']!);
  }

  @override
  Future<({String id, String status, String? reason})> insertDeed(QueuedDeed deed) async {
    s._net();
    final id = 'deed-${s.deeds.length + 1}';
    s.deeds.add({'id': id, 'photo_url': deed.photoOnServer ? deed.photoPath : null, 'status': 'approved', 'type': deed.type});
    if (s.loseNextInsertAnswer) {
      s.loseNextInsertAnswer = false;
      throw const SocketException('Connection reset by peer');
    }
    if (s.killAfterNextInsert) {
      s.killAfterNextInsert = false;
      throw StateError('app killed');
    }
    return (id: id, status: 'approved', reason: null);
  }

  @override
  Future<void> afterInsert(QueuedDeed deed) async => s.afterInsertCalls++;
}

Uint8List photo(int seed) => Uint8List.fromList(List.generate(64, (i) => (i * 7 + seed) % 256));

QueuedDeed deed(String id, {String type = 'litter', String? photoPath, DateTime? at}) => QueuedDeed(
      id: id,
      uid: uid,
      type: type,
      details: const {},
      campaignId: null,
      shareLocation: true,
      afterDuplicate: false,
      gpsLat: 24.86,
      gpsLng: 67.0,
      queuedAt: at ?? DateTime.now(),
      points: 10,
      photoPath: photoPath ?? '$uid/$id.jpg',
    );

void main() {
  late Directory dir;
  late DeedQueueStore store;
  late FakeServer server;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ak_queue_test');
    store = DeedQueueStore(() async => dir);
    server = FakeServer();
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Directory photoDir() => Directory('${dir.path}/offline_queue/photos');
  int photoFiles() => photoDir().existsSync() ? photoDir().listSync().length : 0;

  Future<DeedQueue> restart() async {
    final q = DeedQueue(store);
    await q.loadFor(uid);
    return q;
  }

  test('queued deed is saved to disk with its photo, survives a restart, then sends once', () async {
    final q = await restart();
    expect(await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg'), QueueAddResult.added);
    expect(photoFiles(), 1);

    final q2 = await restart(); // app killed and reopened
    expect(q2.items.single.id, 'a');
    final r = await q2.sendAll(FakeOps(server));
    expect(r.sent.single.deedId, 'deed-1');
    expect(server.deeds, hasLength(1));
    expect(server.deeds.single['photo_url'], '$uid/a.jpg');
    expect(q2.isEmpty, isTrue);
    expect(photoFiles(), 0, reason: 'photo deleted once its deed is inserted');
    expect((await restart()).isEmpty, isTrue);
  });

  test('offline: nothing is dropped, the deed retries with backoff, then sends', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.offline = true;
    final r = await q.sendAll(FakeOps(server));
    expect(r.networkError, isTrue);
    expect(q.items.single.attempts, 1);
    expect(q.items.single.nextAttemptAt, isNotNull);
    expect((await q.sendAll(FakeOps(server))).sent, isEmpty, reason: 'still backing off');

    server.offline = false;
    expect((await q.sendAll(FakeOps(server), ignoreBackoff: true)).sent, hasLength(1));
    expect(server.deeds, hasLength(1));
  });

  test("409 on its OWN earlier upload (answer lost) is not a duplicate: photo reused, one deed", () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.loseNextUploadAnswer = true;
    final first = await q.sendAll(FakeOps(server));
    expect(first.networkError, isTrue);
    expect(q.items.single.stage, QueueStage.queued);
    expect(server.objects, contains('$uid/a.jpg'));

    final second = await (await restart()).sendAll(FakeOps(server), ignoreBackoff: true);
    expect(second.rejected, isEmpty);
    expect(second.sent, hasLength(1));
    expect(server.deeds, hasLength(1));
  });

  test('409 and the deed check loses its connection: retried later, never rejected', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.objects.add('$uid/a.jpg');
    server.deedCheckOffline = true;
    final r = await q.sendAll(FakeOps(server));
    expect(r.rejected, isEmpty);
    expect(r.networkError, isTrue);
    expect(q.items, hasLength(1));
  });

  test('insert answer lost: the retry adopts the deed instead of inserting it twice', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.loseNextInsertAnswer = true;
    expect((await q.sendAll(FakeOps(server))).networkError, isTrue);
    expect(q.items.single.stage, QueueStage.photoUploaded, reason: 'upload step is saved, not repeated');

    final r = await q.sendAll(FakeOps(server), ignoreBackoff: true);
    expect(r.sent.single.deedId, 'deed-1');
    expect(server.deeds, hasLength(1));
    expect(server.afterInsertCalls, 1);
  });

  test('app killed right after the insert: after restart exactly one deed, follow-up runs once', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.killAfterNextInsert = true;
    await q.sendAll(FakeOps(server));
    expect(server.deeds, hasLength(1));

    final q2 = await restart();
    expect(q2.items.single.stage, QueueStage.photoUploaded);
    final r = await q2.sendAll(FakeOps(server), ignoreBackoff: true);
    expect(r.sent, hasLength(1));
    expect(server.deeds, hasLength(1), reason: 'never double-sent');
    expect(server.afterInsertCalls, 1);
    expect(photoFiles(), 0);
  });

  test('photo already used on a sent deed: rejected on send, removed, photo deleted', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    server.objects.add('$uid/a.jpg');
    server.deeds.add({'id': 'old', 'photo_url': '$uid/a.jpg', 'status': 'approved'});
    final r = await q.sendAll(FakeOps(server));
    expect(r.rejected.single.id, 'a');
    expect(q.isEmpty, isTrue);
    expect(photoFiles(), 0);
    expect(server.deeds, hasLength(1));
  });

  test('oldest first, one at a time; a failure stops the rest so order is kept', () async {
    final q = await restart();
    final t = DateTime(2026, 10, 7, 9);
    await q.add(deed('a', at: t), cleanPhoto: photo(1), photoExtension: 'jpg');
    await q.add(deed('b', at: t.add(const Duration(hours: 1))), cleanPhoto: photo(2), photoExtension: 'jpg');
    await q.add(deed('c', at: t.add(const Duration(hours: 2))), cleanPhoto: photo(3), photoExtension: 'jpg');
    server.loseNextInsertAnswer = true;
    final r1 = await q.sendAll(FakeOps(server));
    expect(r1.sent, isEmpty);
    expect(q.items.map((d) => d.id), ['a', 'b', 'c']);
    final r2 = await q.sendAll(FakeOps(server), ignoreBackoff: true);
    expect(r2.sent.map((d) => d.id), ['a', 'b', 'c']);
    expect(server.deeds.map((d) => d['photo_url']), ['$uid/a.jpg', '$uid/b.jpg', '$uid/c.jpg']);
  });

  test('same photo twice in the queue is refused; the queue caps at 20', () async {
    final q = await restart();
    expect(await q.add(deed('a', photoPath: '$uid/same.jpg'), cleanPhoto: photo(1), photoExtension: 'jpg'), QueueAddResult.added);
    expect(await q.add(deed('b', photoPath: '$uid/same.jpg'), cleanPhoto: photo(1), photoExtension: 'jpg'), QueueAddResult.duplicatePhoto);
    for (var i = 0; i < 19; i++) {
      expect(await q.add(deed('n$i')), QueueAddResult.added);
    }
    expect(q.items, hasLength(DeedQueue.maxItems));
    expect(await q.add(deed('over')), QueueAddResult.full);
  });

  test('a queue saved by another account is wiped, never sent', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    final other = DeedQueue(store);
    await other.loadFor('user-b');
    expect(other.isEmpty, isTrue);
    expect(photoFiles(), 0);
    expect(File('${dir.path}/offline_queue/queue.json').existsSync(), isFalse);
  });

  test('sign-out wipe deletes queue + photos, and a send in flight writes nothing back', () async {
    final q = await restart();
    await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
    final slow = _SlowOps(FakeOps(server));
    final sending = q.sendAll(slow);
    await slow.started;
    await q.wipe();
    slow.release();
    final r = await sending;
    expect(r.sent, isEmpty);
    expect(Directory('${dir.path}/offline_queue').existsSync(), isFalse);
  });

  test('orphan photo (killed between photo and queue write) is cleaned up on load', () async {
    await store.writePhoto('ghost', 'jpg', photo(9));
    expect(photoFiles(), 1);
    await restart();
    expect(photoFiles(), 0);
  });

  test('backoff grows and is capped at 10 minutes', () {
    expect(DeedQueue.backoff(1), const Duration(seconds: 15));
    expect(DeedQueue.backoff(2), const Duration(seconds: 30));
    expect(DeedQueue.backoff(20), const Duration(minutes: 10));
  });

  group('AppState with the queue', () {
    test('waiting deeds count toward cooldowns, including after a profile reload', () async {
      final q = DeedQueue(store);
      final state = AppState(deedQueue: q, homeCache: HomeCache(() async => dir));
      await q.add(deed('a', type: 'litter', at: DateTime.now().subtract(const Duration(minutes: 5))));
      state.mergeQueuedCooldowns();
      expect(state.cooldownRemaining('litter'), greaterThan(const Duration(minutes: 50)));
      expect(state.isGlobalCooldownActive, isTrue, reason: 'the global 15-min cooldown counts it too');

      state.applyHomeData(const HomeData(profile: {'id': uid, 'name': 'A', 'points': 5}, deeds: [], badges: [], frozenBadges: [], hallOfFameClaims: [], membership: []));
      expect(state.cooldownRemaining('litter'), greaterThan(const Duration(minutes: 50)));
      expect(state.user.points, 5, reason: 'waiting points are never added to the total');
      expect(state.waitingPoints, 10);
    });

    test('a waiting deed shows its badge as WAITING without granting it', () async {
      final q = DeedQueue(store);
      final state = AppState(deedQueue: q, homeCache: HomeCache(() async => dir));
      await q.add(deed('a'));
      expect(state.waitingBadgeIds, contains('firstStep'));
      expect(state.user.badges, isNot(contains('firstStep')));
      expect(state.deedsLog, isEmpty);
    });

    test('wipeOfflineData clears the queue, its photos and the Home cache', () async {
      final q = DeedQueue(store);
      final cache = HomeCache(() async => dir);
      final state = AppState(deedQueue: q, homeCache: cache);
      await q.add(deed('a'), cleanPhoto: photo(1), photoExtension: 'jpg');
      await cache.save(uid, const HomeData(profile: {'id': uid, 'name': 'A'}, deeds: [], badges: [], frozenBadges: [], hallOfFameClaims: [], membership: []));
      state.isOffline = true;
      await state.wipeOfflineData();
      expect(q.isEmpty, isTrue);
      expect(photoFiles(), 0);
      expect(await cache.load(uid), isNull);
      expect(state.isOffline, isFalse);
    });
  });

  group('Home cache', () {
    const data = HomeData(
      profile: {'id': uid, 'name': 'Ayesha Khan', 'email': 'a@example.com', 'phone': '0300', 'city': 'Karachi', 'points': 40},
      deeds: [{'id': 'd1', 'type': 'litter', 'points': 10, 'created_at': '2026-10-01T10:00:00Z', 'status': 'approved', 'campaign_id': null}],
      badges: [{'badge_id': 'firstStep'}],
      frozenBadges: null,
      hallOfFameClaims: [],
      membership: [{'membership_number': 'AK-100001'}],
    );

    test('round-trips what Home needs, without email or phone', () async {
      final cache = HomeCache(() async => dir);
      await cache.save(uid, data);
      final raw = File('${dir.path}/offline_cache/home.json').readAsStringSync();
      expect(raw, isNot(contains('a@example.com')));
      expect(raw, isNot(contains('0300')));
      final back = (await cache.load(uid))!;
      expect(back.profile['name'], 'Ayesha Khan');
      expect(back.profile.containsKey('email'), isFalse);
      expect(back.deeds!.single['type'], 'litter');
      expect(back.frozenBadges, isNull);
      expect(back.membership!.single['membership_number'], 'AK-100001');
    });

    test("another account's snapshot is never returned, and is deleted", () async {
      final cache = HomeCache(() async => dir);
      await cache.save(uid, data);
      expect(await cache.load('user-b'), isNull);
      expect(await cache.load(uid), isNull);
    });

    test('opening from cache keeps already-loaded email/phone (keys absent, not null)', () {
      final state = AppState(deedQueue: DeedQueue(store), homeCache: HomeCache(() async => dir));
      state.user.email = 'kept@example.com';
      state.applyHomeData(HomeData.fromCacheJson(data.toCacheJson()));
      expect(state.user.email, 'kept@example.com');
      expect(state.user.name, 'Ayesha Khan');
      expect(state.membershipNumber, 'AK-100001');
    });
  });
}

// Holds the first upload until released, to wipe the queue mid-send.
class _SlowOps implements DeedSendOps {
  final FakeOps inner;
  _SlowOps(this.inner);
  final _started = Completer<void>();
  final _release = Completer<void>();
  Future<void> get started => _started.future;
  void release() => _release.complete();

  @override
  Future<PhotoUploadResult> uploadPhoto(String path, Uint8List bytes) async {
    _started.complete();
    await _release.future;
    return inner.uploadPhoto(path, bytes);
  }

  @override
  Future<({String id, String status})?> findDeedByPhoto(String photoPath) => inner.findDeedByPhoto(photoPath);
  @override
  Future<({String id, String status, String? reason})> insertDeed(QueuedDeed deed) => inner.insertDeed(deed);
  @override
  Future<void> afterInsert(QueuedDeed deed) => inner.afterInsert(deed);
}
