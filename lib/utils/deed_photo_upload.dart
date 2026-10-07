import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'image_metadata.dart';
import 'network_errors.dart';

// Deed photo upload with duplicate detection. The storage object is named after the SHA-256 of
// the cleaned bytes (uid/<sha256>.<ext>), and uploaded with upsert off, so uploading the same
// photo again fails with "already exists". That's the duplicate signal: no table, no schema
// change. Only this user's own earlier photos are caught (the path starts with their uid), and
// only photos uploaded since this change (older ones are named by timestamp).
//
// An existing object isn't always a duplicate: if an earlier submission uploaded the photo but
// its deed row then failed to save, the photo is sitting there unused. So "already exists" only
// counts as a duplicate when one of the user's deeds actually uses that photo; otherwise the
// existing object is simply reused.
//
// unreachable (offline mode): the server couldn't be reached at all, so nothing is known yet.
// The caller keeps the deed queued instead of treating it as failed or duplicate.
enum PhotoUploadStatus { uploaded, duplicate, failed, unreachable }

class PhotoUploadResult {
  final PhotoUploadStatus status;
  final String? path; // storage path when uploaded (or reused), else null
  const PhotoUploadResult(this.status, [this.path]);
}

typedef PhotoUploadFn = Future<void> Function(String path, Uint8List bytes);
typedef DeedUsesPhotoFn = Future<bool> Function(String path);

// A cleaned photo and the storage path it will be uploaded to. Prepared once: the offline queue
// stores exactly these bytes (metadata already gone) and uploads them later under this path.
class PreparedDeedPhoto {
  final Uint8List bytes;
  final String extension;
  final String path;
  const PreparedDeedPhoto({required this.bytes, required this.extension, required this.path});
}

// Strips metadata (EXIF GPS, XMP...) and names the photo by its content hash. Null if the photo
// can't be cleaned — then nothing may be uploaded or stored.
Future<PreparedDeedPhoto?> prepareDeedPhoto(String uid, Uint8List photoBytes) async {
  final clean = await stripImageMetadata(photoBytes);
  if (clean == null) return null;
  return PreparedDeedPhoto(bytes: clean.bytes, extension: clean.extension, path: '$uid/${sha256.convert(clean.bytes)}.${clean.extension}');
}

Future<PhotoUploadResult> uploadDeedPhoto({
  required String uid,
  required Uint8List photoBytes,
  required PhotoUploadFn upload,
  required DeedUsesPhotoFn deedUsesPhoto,
}) async {
  final prepared = await prepareDeedPhoto(uid, photoBytes);
  if (prepared == null) return const PhotoUploadResult(PhotoUploadStatus.failed); // never upload uncleaned bytes
  return uploadPreparedDeedPhoto(prepared.path, prepared.bytes, upload: upload, deedUsesPhoto: deedUsesPhoto);
}

Future<PhotoUploadResult> uploadPreparedDeedPhoto(
  String path,
  Uint8List cleanBytes, {
  required PhotoUploadFn upload,
  required DeedUsesPhotoFn deedUsesPhoto,
}) async {
  try {
    await upload(path, cleanBytes);
    return PhotoUploadResult(PhotoUploadStatus.uploaded, path);
  } catch (e) {
    if (!isAlreadyExistsError(e)) {
      return PhotoUploadResult(isNetworkError(e) ? PhotoUploadStatus.unreachable : PhotoUploadStatus.failed);
    }
    try {
      return await deedUsesPhoto(path)
          ? const PhotoUploadResult(PhotoUploadStatus.duplicate)
          : PhotoUploadResult(PhotoUploadStatus.uploaded, path); // left over from a failed submit: reuse
    } catch (e) {
      // Connection dropped between the two calls: unknown, not a duplicate. (An offline-queued
      // deed must never be thrown away as a "duplicate" of its own earlier upload.)
      if (isNetworkError(e)) return const PhotoUploadResult(PhotoUploadStatus.unreachable);
      return const PhotoUploadResult(PhotoUploadStatus.duplicate); // can't tell: the object exists, so err on "duplicate"
    }
  }
}

// Supabase Storage answers an upload to an existing path (upsert off) with
// {"statusCode":"409","error":"Duplicate","message":"The resource already exists"}; the client
// turns that into a StorageException. Newer servers name it ResourceAlreadyExists. Matched loosely
// on purpose. NOT yet confirmed against our live bucket + policies (see the v1.3.2 report).
bool isAlreadyExistsError(Object e) {
  if (e is! StorageException) return false;
  final error = (e.error ?? '').toLowerCase();
  return e.statusCode == '409' ||
      error == 'duplicate' ||
      error == 'resourcealreadyexists' ||
      e.message.toLowerCase().contains('already exists');
}
