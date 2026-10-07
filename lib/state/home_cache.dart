import 'dart:convert';
import 'dart:io';
import 'home_data.dart';

// Offline mode: the last Home snapshot that loaded successfully, so a cold start without internet
// can still open Home. One file, <app-private dir>/offline_cache/home.json, tagged with the uid
// it belongs to: a snapshot for any other account is deleted, never shown. Wiped on sign-out.
// Holds only what Home/Profile show (no email/phone — see HomeData.toCacheJson).
class HomeCache {
  final Future<Directory> Function() baseDir;
  HomeCache(this.baseDir);

  Future<File> _file() async => File('${(await baseDir()).path}${Platform.pathSeparator}offline_cache${Platform.pathSeparator}home.json');

  Future<void> save(String uid, HomeData data) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({'v': 1, 'uid': uid, 'savedAt': DateTime.now().toUtc().toIso8601String(), 'data': data.toCacheJson()}), flush: true);
    await tmp.rename(f.path); // atomic: a kill mid-write keeps the previous snapshot
  }

  Future<HomeData?> load(String uid) async {
    final f = await _file();
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['uid'] != uid) {
        await clear(); // another account's snapshot: never shown
        return null;
      }
      return HomeData.fromCacheJson(Map<String, dynamic>.from(j['data'] as Map));
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
