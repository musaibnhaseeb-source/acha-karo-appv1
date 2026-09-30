import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'package:acha_karo/state/app_state.dart' show deedModerationReasons;
import 'package:acha_karo/utils/deed_photo_upload.dart';
import 'package:acha_karo/utils/image_metadata.dart';

// v1.3.2 duplicate photos: content-hash object names + upsert-off upload. A fake bucket stands in
// for Supabase Storage and answers an existing path the way Storage does (409 Duplicate).

class _FakeBucket {
  final objects = <String, Uint8List>{};
  final usedByDeeds = <String>{}; // paths some deed row points at
  Future<void> upload(String path, Uint8List bytes) async {
    if (objects.containsKey(path)) {
      throw const StorageException('The resource already exists', statusCode: '409', error: 'Duplicate');
    }
    objects[path] = bytes;
  }

  Future<bool> deedUsesPhoto(String path) async => usedByDeeds.contains(path);

  // What a full submission does: upload, then (if it got a path) a deed row that uses it.
  Future<PhotoUploadResult> submit(String uid, Uint8List photo) async {
    final r = await uploadDeedPhoto(uid: uid, photoBytes: photo, upload: upload, deedUsesPhoto: deedUsesPhoto);
    if (r.status == PhotoUploadStatus.uploaded) usedByDeeds.add(r.path!);
    return r;
  }
}

Uint8List _fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

void main() {
  const uid = 'user-a';

  test('same photo twice: the second is rejected as a duplicate', () async {
    final bucket = _FakeBucket();
    final first = await bucket.submit(uid, _fixture('gps_exif_upright.jpg'));
    expect(first.status, PhotoUploadStatus.uploaded);
    expect(first.path, matches(RegExp(r'^user-a/[0-9a-f]{64}\.jpg$')));
    final second = await bucket.submit(uid, _fixture('gps_exif_upright.jpg'));
    expect(second.status, PhotoUploadStatus.duplicate);
    expect(second.path, isNull);
    expect(bucket.objects, hasLength(1));
  });

  test('different photos: both upload normally', () async {
    final bucket = _FakeBucket();
    final a = await bucket.submit(uid, _fixture('gps_exif_upright.jpg'));
    final b = await bucket.submit(uid, _fixture('gps_exif.jpg'));
    expect([a.status, b.status], [PhotoUploadStatus.uploaded, PhotoUploadStatus.uploaded]);
    expect(a.path, isNot(b.path));
  });

  test('the same picture with different metadata is still a duplicate (hash is of the cleaned bytes)', () async {
    final bucket = _FakeBucket();
    final original = _fixture('gps_exif_upright.jpg');
    final alreadyClean = stripJpegMetadata(original)!; // same pixels, no EXIF/GPS
    expect(alreadyClean, isNot(original));
    await bucket.submit(uid, original);
    expect((await bucket.submit(uid, alreadyClean)).status, PhotoUploadStatus.duplicate);
  });

  test('another user uploading the same photo is not a duplicate (own photos only)', () async {
    final bucket = _FakeBucket();
    await bucket.submit('user-a', _fixture('gps_exif_upright.jpg'));
    expect((await bucket.submit('user-b', _fixture('gps_exif_upright.jpg'))).status, PhotoUploadStatus.uploaded);
  });

  test('an existing photo no deed uses (earlier deed save failed) is reused, not rejected', () async {
    final bucket = _FakeBucket();
    final orphan = await uploadDeedPhoto(uid: uid, photoBytes: _fixture('gps_exif.jpg'), upload: bucket.upload, deedUsesPhoto: bucket.deedUsesPhoto);
    // ...deed insert failed, so nothing uses it. Retrying with the same photo:
    final retry = await bucket.submit(uid, _fixture('gps_exif.jpg'));
    expect(retry.status, PhotoUploadStatus.uploaded);
    expect(retry.path, orphan.path);
  });

  test('if the deed check itself fails, an existing photo counts as a duplicate', () async {
    final bucket = _FakeBucket();
    await bucket.submit(uid, _fixture('gps_exif.jpg'));
    final r = await uploadDeedPhoto(uid: uid, photoBytes: _fixture('gps_exif.jpg'), upload: bucket.upload, deedUsesPhoto: (_) async => throw Exception('offline'));
    expect(r.status, PhotoUploadStatus.duplicate);
  });

  test('any other upload failure behaves as before: failed, no path', () async {
    final r = await uploadDeedPhoto(
      uid: uid,
      photoBytes: _fixture('gps_exif.jpg'),
      upload: (_, __) async => throw const StorageException('new row violates row-level security policy', statusCode: '403', error: 'Unauthorized'),
      deedUsesPhoto: (_) async => true,
    );
    expect(r.status, PhotoUploadStatus.failed);
    expect(r.path, isNull);
  });

  test('isAlreadyExistsError: storage duplicate shapes yes, anything else no', () {
    expect(isAlreadyExistsError(const StorageException('The resource already exists', statusCode: '409', error: 'Duplicate')), isTrue);
    expect(isAlreadyExistsError(const StorageException('The resource already exists', statusCode: '400', error: 'Duplicate')), isTrue);
    expect(isAlreadyExistsError(const StorageException('Asset Already Exists', statusCode: '409', error: 'ResourceAlreadyExists')), isTrue);
    expect(isAlreadyExistsError(const StorageException('new row violates row-level security policy', statusCode: '403', error: 'Unauthorized')), isFalse);
    expect(isAlreadyExistsError(const StorageException('Payload too large', statusCode: '413')), isFalse);
    expect(isAlreadyExistsError(Exception('SocketException')), isFalse);
  });

  test('a resubmission after a duplicate is always moderated, with its own reason', () {
    final normal = deedModerationReasons(repeat: false, shareLocation: true, gpsFailed: false, isDonation: false, afterDuplicate: false);
    expect(normal, isEmpty); // would be approved straight away
    final after = deedModerationReasons(repeat: false, shareLocation: true, gpsFailed: false, isDonation: false, afterDuplicate: true);
    expect(after, ['Resubmitted after a duplicate photo was rejected.']);
  });
}
