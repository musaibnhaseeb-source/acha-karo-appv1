import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

// True when an error means "couldn't reach the server" (no internet, DNS, timeout, dropped
// connection), as opposed to the server answering with an error. Offline mode keys off this: a
// network error keeps a deed queued for later; a server answer is handled as before.
//
// Shapes seen from the Supabase client:
// - database calls (postgrest) let the raw SocketException / http ClientException /
//   TimeoutException through
// - storage wraps it in a StorageException whose statusCode is the error's TYPE NAME (e.g.
//   "ClientException"), not an HTTP status number
// - auth refresh failures offline are AuthRetryableFetchException
bool isNetworkError(Object e) {
  if (e is SocketException || e is TimeoutException || e is HandshakeException || e is HttpException) return true;
  if (e is StorageException) return int.tryParse(e.statusCode ?? '') == null;
  final type = e.runtimeType.toString();
  return type.contains('ClientException') || type.contains('RetryableFetch');
}
