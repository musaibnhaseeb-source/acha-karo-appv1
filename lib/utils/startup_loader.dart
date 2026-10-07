import 'dart:async';

// Runs the cold-start profile load (M1 fix: it used to hang forever offline). Reports:
// - found / missing as soon as a load succeeds, from ANY attempt, even one that already timed
//   out, so a slow-but-successful load always wins over the offline state
// - failed when the current attempt throws, or hasn't finished after [timeout]
// A failure from an older attempt (after a retry started a newer one) is ignored. Once a load
// succeeds, or after dispose(), nothing more is reported.
enum StartupOutcome { found, missing, failed }

class StartupLoader {
  final Future<bool> Function() load;
  final void Function(StartupOutcome) onOutcome;
  final Duration timeout;
  StartupLoader({required this.load, required this.onOutcome, this.timeout = const Duration(seconds: 15)});

  int _attempt = 0;
  // Why the current attempt failed: the thrown error, or null when it timed out. Lets the caller
  // tell "no internet" from "the server answered with an error" (never shown as offline).
  Object? lastError;
  bool _done = false;
  Timer? _timer;

  void start() {
    if (_done) return;
    final attempt = ++_attempt;
    _timer?.cancel();
    _timer = Timer(timeout, () {
      if (!_done && attempt == _attempt) {
        lastError = null;
        onOutcome(StartupOutcome.failed);
      }
    });
    Future<bool> future;
    try {
      future = load();
    } catch (e) {
      future = Future.error(e);
    }
    future.then((found) {
      if (_done) return;
      _done = true;
      _timer?.cancel();
      onOutcome(found ? StartupOutcome.found : StartupOutcome.missing);
    }, onError: (Object e) {
      if (_done || attempt != _attempt) return;
      _timer?.cancel();
      lastError = e;
      onOutcome(StartupOutcome.failed);
    });
  }

  void dispose() {
    _done = true;
    _timer?.cancel();
  }
}
