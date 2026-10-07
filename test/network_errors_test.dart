import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException, PostgrestException;
import 'package:acha_karo/utils/network_errors.dart';
import 'package:acha_karo/utils/deed_photo_upload.dart';

// Offline mode keys off "couldn't reach the server" vs "the server answered with an error".

void main() {
  test('no connection / timeouts / storage-wrapped client errors are network errors', () {
    expect(isNetworkError(const SocketException('Failed host lookup')), isTrue);
    expect(isNetworkError(TimeoutException('t')), isTrue);
    expect(isNetworkError(const StorageException('Connection closed', statusCode: 'ClientException')), isTrue);
    expect(isNetworkError(const StorageException('x')), isTrue); // no status at all: never reached the server
  });

  test('server answers are not network errors', () {
    expect(isNetworkError(const StorageException('The resource already exists', statusCode: '409', error: 'Duplicate')), isFalse);
    expect(isNetworkError(const StorageException('rls', statusCode: '403')), isFalse);
    expect(isNetworkError(const PostgrestException(message: 'violates check constraint', code: '23514')), isFalse);
    expect(isNetworkError(Exception('something else')), isFalse);
  });

  test('upload with no connection is "unreachable", not failed or duplicate', () async {
    final r = await uploadPreparedDeedPhoto('u/x.jpg', Uint8List(4),
        upload: (_, __) async => throw const StorageException('Failed host lookup', statusCode: 'SocketException'), deedUsesPhoto: (_) async => false);
    expect(r.status, PhotoUploadStatus.unreachable);
  });
}
