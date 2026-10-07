import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../utils/deed_photo_upload.dart';
import '../utils/network_errors.dart';

// Offline mode: deeds done without internet wait here, on the phone, until the app is open and
// online again. Then they go out one at a time, oldest first, through the normal submit rules.
//
// Each deed moves through these stages, and the stage is written to disk BEFORE the next network
// step starts, so a crash or kill at any point resumes from the right place:
//
//   queued ──upload photo──▶ photoUploaded ──insert deed──▶ inserted ──follow-up──▶ done ──▶ removed
//     │                         │                             (moderation_queue row,
//     │ photo already used      │ a deed with this photo       or the points update)
//     ▼ on another deed         │ already exists = our own
//   rejected (removed,          │ earlier insert whose answer
//   waiting points vanish)      ▼ was lost: adopt it, never insert twice
//
// Why this is safe:
// - Never two inserts: a deed is only inserted from photoUploaded, and first we look for a deed
//   already using this photo (the photo path is a content hash, unique to this user). Found =
//   our own insert landed before a crash, so it's adopted instead of inserted again.
// - The 409 trap: if the photo uploaded but the app died before saving photoUploaded, the retry
//   upload answers "already exists". No deed uses that photo yet, so it's reused (upload logic
//   in deed_photo_upload.dart), not treated as a duplicate. If the connection drops during that
//   check it's "unreachable" (retry later), never "duplicate".
// - Never dropped silently: any failure keeps the deed and retries with backoff. The only ways
//   out are: sent, rejected by the server as a duplicate photo (the person is told), or sign-out.
//
// PII: the queue file and photos live in app-private storage only (see DeedQueueStore). Photos
// are stored AFTER metadata stripping, and each one is deleted as soon as its deed is inserted.

enum QueueStage { queued, photoUploaded, inserted, done }

class QueuedDeed {
  final String id; // local only
  final String uid; // the account that did it; a queue for another uid is wiped, never sent
  final String type;
  final Map<String, String> details;
  final String? campaignId;
  final bool shareLocation;
  final bool afterDuplicate;
  final double? gpsLat; // captured when the deed was done (same consent as online)
  final double? gpsLng;
  final DateTime queuedAt;
  final int points; // catalog points when done — shown as "waiting", never added until sent
  final String? photoPath; // storage path (uid/<sha256>.<ext>); also the local duplicate key
  String? photoFile; // file name in the queue's photo folder; null once deleted (or none)
  bool photoOnServer; // the photo is uploaded at photoPath; only then may the deed point at it
  QueueStage stage;
  String? deedId;
  String? deedStatus; // 'approved' | 'pending' once inserted
  String? reason; // moderation reason, for the follow-up of a pending deed
  int attempts;
  DateTime? nextAttemptAt;

  QueuedDeed({
    required this.id,
    required this.uid,
    required this.type,
    required this.details,
    required this.campaignId,
    required this.shareLocation,
    required this.afterDuplicate,
    required this.gpsLat,
    required this.gpsLng,
    required this.queuedAt,
    required this.points,
    required this.photoPath,
    this.photoFile,
    this.photoOnServer = false,
    this.stage = QueueStage.queued,
    this.deedId,
    this.deedStatus,
    this.reason,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'type': type,
        'details': details,
        'campaignId': campaignId,
        'shareLocation': shareLocation,
        'afterDuplicate': afterDuplicate,
        'gpsLat': gpsLat,
        'gpsLng': gpsLng,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'points': points,
        'photoPath': photoPath,
        'photoFile': photoFile,
        'photoOnServer': photoOnServer,
        'stage': stage.name,
        'deedId': deedId,
        'deedStatus': deedStatus,
        'reason': reason,
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
      };

  factory QueuedDeed.fromJson(Map<String, dynamic> j) => QueuedDeed(
        id: j['id'] as String,
        uid: j['uid'] as String,
        type: j['type'] as String,
        details: Map<String, String>.from(j['details'] as Map? ?? const {}),
        campaignId: j['campaignId'] as String?,
        shareLocation: j['shareLocation'] as bool? ?? false,
        afterDuplicate: j['afterDuplicate'] as bool? ?? false,
        gpsLat: (j['gpsLat'] as num?)?.toDouble(),
        gpsLng: (j['gpsLng'] as num?)?.toDouble(),
        queuedAt: DateTime.parse(j['queuedAt'] as String).toLocal(),
        points: j['points'] as int? ?? 0,
        photoPath: j['photoPath'] as String?,
        photoFile: j['photoFile'] as String?,
        photoOnServer: j['photoOnServer'] as bool? ?? false,
        stage: QueueStage.values.byName(j['stage'] as String? ?? 'queued'),
        deedId: j['deedId'] as String?,
        deedStatus: j['deedStatus'] as String?,
        reason: j['reason'] as String?,
        attempts: j['attempts'] as int? ?? 0,
        nextAttemptAt: j['nextAttemptAt'] != null ? DateTime.parse(j['nextAttemptAt'] as String).toLocal() : null,
      );
}

// Files: <app-private dir>/offline_queue/queue.json and .../offline_queue/photos/<id>.<ext>.
// The base directory comes from path_provider's getApplicationSupportDirectory() in the app:
// private to the app, not the gallery, not external storage, removed on uninstall.
class DeedQueueStore {
  final Future<Directory> Function() baseDir;
  DeedQueueStore(this.baseDir);

  Future<Directory> _dir() async => Directory('${(await baseDir()).path}${Platform.pathSeparator}offline_queue');
  Future<Directory> _photoDir() async => Directory('${(await _dir()).path}${Platform.pathSeparator}photos');
  Future<File> _queueFile() async => File('${(await _dir()).path}${Platform.pathSeparator}queue.json');

  Future<List<QueuedDeed>> load() async {
    final f = await _queueFile();
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (raw['items'] as List).map((e) => QueuedDeed.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      // A half-written file can't happen (writes are atomic, see save), so this is real
      // corruption. Kept aside rather than deleted, and the queue starts empty.
      try {
        await f.rename('${f.path}.corrupt');
      } catch (_) {}
      return [];
    }
  }

  // Write to a temp file, then rename over the real one: a kill mid-write leaves the previous
  // complete file, never a half-written one.
  Future<void> save(List<QueuedDeed> items) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final f = await _queueFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({'v': 1, 'items': items.map((e) => e.toJson()).toList()}), flush: true);
    await tmp.rename(f.path);
  }

  Future<String> writePhoto(String id, String extension, Uint8List bytes) async {
    final dir = await _photoDir();
    await dir.create(recursive: true);
    final name = '$id.$extension';
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<Uint8List?> readPhoto(String name) async {
    final f = File('${(await _photoDir()).path}${Platform.pathSeparator}$name');
    return await f.exists() ? await f.readAsBytes() : null;
  }

  Future<void> deletePhoto(String name) async {
    final f = File('${(await _photoDir()).path}${Platform.pathSeparator}$name');
    if (await f.exists()) await f.delete();
  }

  // Photos no queued deed refers to (e.g. the app died between saving the photo and the queue).
  Future<void> deleteOrphanPhotos(Set<String> keep) async {
    final dir = await _photoDir();
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && !keep.contains(name)) await e.delete();
    }
  }

  // Sign-out: the queue, every queued photo, all of it.
  Future<void> wipe() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

// The network steps, supplied by AppState (Supabase) or by tests (fakes).
abstract class DeedSendOps {
  // Upload the already-cleaned photo to its content-hash path (see uploadPreparedDeedPhoto).
  Future<PhotoUploadResult> uploadPhoto(String path, Uint8List bytes);
  // This user's deed using this photo, if one exists. Throws if it can't be checked.
  Future<({String id, String status})?> findDeedByPhoto(String photoPath);
  // Decide approved/pending exactly like an online submit and insert the deeds row. Throws on failure.
  Future<({String id, String status, String? reason})> insertDeed(QueuedDeed deed);
  // moderation_queue row (pending) or the points update (approved). Best-effort, like online.
  Future<void> afterInsert(QueuedDeed deed);
}

enum QueueAddResult { added, full, duplicatePhoto }

class QueueSendResult {
  final List<QueuedDeed> sent = [];
  final List<QueuedDeed> rejected = []; // duplicate photo: removed, the person is told
  bool networkError = false; // stopped because the server couldn't be reached
}

class DeedQueue {
  static const maxItems = 20;

  final DeedQueueStore store;
  final DateTime Function() clock;
  DeedQueue(this.store, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  List<QueuedDeed> _items = [];
  String? _loadedUid;
  int _generation = 0; // bumped by wipe(); a send still in flight from before then stops
  bool _sending = false;

  List<QueuedDeed> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isFull => _items.length >= maxItems;
  int get waitingPoints => _items.fold(0, (sum, d) => sum + d.points);
  bool hasPhoto(String photoPath) => _items.any((d) => d.photoPath == photoPath);
  DateTime? get nextAttemptAt => _items.isEmpty ? null : _items.first.nextAttemptAt;

  // Loads the saved queue for this account (once per session). A queue left by a different
  // account is wiped, never sent under the wrong user.
  Future<void> loadFor(String uid) async {
    if (_loadedUid == uid) return;
    final gen = _generation;
    var loaded = await store.load();
    if (gen != _generation) return;
    if (loaded.any((d) => d.uid != uid)) {
      await store.wipe();
      loaded = [];
    }
    loaded.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    _items = loaded;
    _loadedUid = uid;
    await store.deleteOrphanPhotos({for (final d in loaded) if (d.photoFile != null) d.photoFile!});
  }

  // Photo bytes must already be metadata-stripped (prepareDeedPhoto). Photo first, then the
  // queue file, so a kill in between leaves at worst an orphan photo (cleaned up on next load),
  // never a queued deed without its photo.
  Future<QueueAddResult> add(QueuedDeed deed, {Uint8List? cleanPhoto, String? photoExtension}) async {
    if (isFull) return QueueAddResult.full;
    if (deed.photoPath != null && hasPhoto(deed.photoPath!)) return QueueAddResult.duplicatePhoto;
    if (cleanPhoto != null) deed.photoFile = await store.writePhoto(deed.id, photoExtension ?? 'jpg', cleanPhoto);
    final next = [..._items, deed];
    await store.save(next);
    _items = next;
    _loadedUid ??= deed.uid;
    return QueueAddResult.added;
  }

  // Sends due deeds one at a time, oldest first. Stops at the first failure so order is kept;
  // that deed gets a backoff. ignoreBackoff: the connection just came back, try now.
  // onSent runs right after each deed is done, before the next one starts (the next deed's
  // points update builds on the points the previous one added).
  Future<QueueSendResult> sendAll(DeedSendOps ops, {bool ignoreBackoff = false, void Function(QueuedDeed deed)? onSent}) async {
    final result = QueueSendResult();
    if (_sending) return result; // single-flight: two sends can never race on the same deed
    _sending = true;
    final gen = _generation;
    try {
      while (_items.isNotEmpty && gen == _generation) {
        final deed = _items.first;
        if (!ignoreBackoff && deed.nextAttemptAt != null && clock().isBefore(deed.nextAttemptAt!)) break;
        final outcome = await _sendOne(deed, ops, gen);
        if (gen != _generation) break;
        if (outcome == _Outcome.sent) {
          result.sent.add(deed);
          onSent?.call(deed);
        } else if (outcome == _Outcome.rejected) {
          result.rejected.add(deed);
        } else {
          result.networkError = outcome == _Outcome.retryNetwork;
          deed.attempts++;
          deed.nextAttemptAt = clock().add(backoff(deed.attempts));
          await _persist(gen);
          break;
        }
      }
    } finally {
      _sending = false;
    }
    return result;
  }

  // 15 s, 30 s, 1 m, 2 m ... capped at 10 minutes.
  static Duration backoff(int attempts) => Duration(seconds: min(15 * pow(2, max(0, attempts - 1)).toInt(), 600));

  Future<_Outcome> _sendOne(QueuedDeed deed, DeedSendOps ops, int gen) async {
    try {
      if (deed.stage == QueueStage.queued) {
        final file = deed.photoFile;
        final bytes = file == null ? null : await store.readPhoto(file);
        if (deed.photoPath != null && bytes != null) {
          final upload = await ops.uploadPhoto(deed.photoPath!, bytes);
          if (gen != _generation) return _Outcome.aborted;
          switch (upload.status) {
            case PhotoUploadStatus.duplicate:
              // The server says this photo is already on one of this user's deeds.
              await _remove(deed, gen);
              return _Outcome.rejected;
            case PhotoUploadStatus.unreachable:
              return _Outcome.retryNetwork;
            case PhotoUploadStatus.failed:
              return _Outcome.retry;
            case PhotoUploadStatus.uploaded:
              deed.photoOnServer = true;
          }
        }
        // No photo (couldn't be cleaned when done, or the file is gone): sent without one, same
        // as an online submit whose upload failed.
        deed.stage = QueueStage.photoUploaded;
        await _persist(gen);
      }

      if (deed.stage == QueueStage.photoUploaded) {
        final existing = deed.photoOnServer ? await ops.findDeedByPhoto(deed.photoPath!) : null;
        if (gen != _generation) return _Outcome.aborted;
        if (existing != null) {
          // Our own insert from before a crash: adopt it.
          deed.deedId = existing.id;
          deed.deedStatus = existing.status;
        } else {
          final row = await ops.insertDeed(deed);
          if (gen != _generation) return _Outcome.aborted;
          deed.deedId = row.id;
          deed.deedStatus = row.status;
          deed.reason = row.reason;
        }
        deed.stage = QueueStage.inserted;
        await _persist(gen);
        // The photo is on the server and attached to the deed: delete the local copy now.
        if (deed.photoFile != null) {
          await store.deletePhoto(deed.photoFile!);
          deed.photoFile = null;
          await _persist(gen);
        }
      }

      if (deed.stage == QueueStage.inserted) {
        await ops.afterInsert(deed);
        deed.stage = QueueStage.done;
        await _persist(gen);
      }

      await _remove(deed, gen);
      return _Outcome.sent;
    } catch (e) {
      return isNetworkError(e) ? _Outcome.retryNetwork : _Outcome.retry;
    }
  }

  Future<void> _persist(int gen) async {
    if (gen == _generation) await store.save(_items);
  }

  Future<void> _remove(QueuedDeed deed, int gen) async {
    if (gen != _generation) return;
    if (deed.photoFile != null) {
      await store.deletePhoto(deed.photoFile!);
      deed.photoFile = null;
    }
    _items = [..._items]..remove(deed);
    await store.save(_items);
  }

  // Sign-out: forget everything in memory and on disk. A send still in flight stops at its next
  // step and writes nothing more.
  Future<void> wipe() async {
    _generation++;
    _items = [];
    _loadedUid = null;
    await store.wipe();
  }
}

enum _Outcome { sent, rejected, retry, retryNetwork, aborted }
