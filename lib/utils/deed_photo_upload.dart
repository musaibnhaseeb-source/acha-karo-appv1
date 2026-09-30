import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'image_metadata.dart';

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
enum PhotoUploadStatus { uploaded, duplicate, failed }

class PhotoUploadResult {
  final PhotoUploadStatus status;
  final String? path; // storage path when uploaded (or reused), else null
  const PhotoUploadResult(this.status, [this.path]);
}

typedef PhotoUploadFn = Future<void> Function(String path, Uint8List bytes);
typedef DeedUsesPhotoFn = Future<bool> Function(String path);

Future<PhotoUploadResult> uploadDeedPhoto({
  required String uid,
  required Uint8List photoBytes,
  required PhotoUploadFn upload,
  required DeedUsesPhotoFn deedUsesPhoto,
}) async {
  final clean = await stripImageMetadata(photoBytes);
  if (clean == null) return const PhotoUploadResult(PhotoUploadStatus.failed); // never upload uncleaned bytes
  final path = '$uid/${sha256.convert(clean.bytes)}.${clean.extension}';
  try {
    await upload(path, clean.bytes);
    return PhotoUploadResult(PhotoUploadStatus.uploaded, path);
  } catch (e) {
    if (!isAlreadyExistsError(e)) return const PhotoUploadResult(PhotoUploadStatus.failed);
    try {
      return await deedUsesPhoto(path)
          ? const PhotoUploadResult(PhotoUploadStatus.duplicate)
          : PhotoUploadResult(PhotoUploadStatus.uploaded, path); // left over from a failed submit: reuse
    } catch (_) {
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
