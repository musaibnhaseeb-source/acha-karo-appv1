// Pure state machine for the side-scroller journey (no Flutter, no I/O), so it can be unit tested.
//
// Guddi walks in place; the world scrolls. worldX is how far along the road she is, in world units;
// targetX is where the user's progress says she should be. Stops sit at (index+1)*step, and progress
// between two stops is interpolated by deeds (same mapping as the design's posFor).
//
// Flow (design: journey_side_v2): idle -> walkStart -> walking -> walkStop -> (celebrate -> hold)
// -> returning (when the next deed starts) -> idle -> walkStart ...

enum GuddiState { idle, walkStart, walking, walkStop, celebrate, hold, returning }

class SideScrollerLogic {
  final List<int> thresholds; // deeds needed per stop, ascending
  final double step; // world units between consecutive stops
  final double walkSpeed; // world units per second at full speed
  final double stopClipSeconds; // length of the walk_stop clip (she decelerates over it)

  GuddiState state = GuddiState.idle;
  double worldX;
  double targetX;
  double _stateTime = 0;
  final Set<int> celebrated = {}; // stop indices already celebrated
  int? arrivedStop; // stop Guddi is standing on, else null

  SideScrollerLogic({
    required this.thresholds,
    this.step = 520,
    this.walkSpeed = 220,
    this.stopClipSeconds = 0.96,
    int startDeeds = 0,
  })  : worldX = 0,
        targetX = 0 {
    worldX = targetX = posFor(startDeeds);
  }

  double get stateTime => _stateTime;

  double stopX(int i) => (i + 1) * step;

  /// World position for a deed count: linear between stops, stop i at (i+1)*step.
  double posFor(int deeds) {
    var prevT = 0;
    var prevS = 0.0;
    for (var i = 0; i < thresholds.length; i++) {
      if (deeds <= thresholds[i]) return prevS + (deeds - prevT) / (thresholds[i] - prevT) * (stopX(i) - prevS);
      prevT = thresholds[i];
      prevS = stopX(i);
    }
    return thresholds.isEmpty ? 0 : stopX(thresholds.length - 1);
  }

  /// Set from the repository's deed count. Going backwards, or [snap], jumps with no walking.
  void setProgress(int deedsDone, {bool snap = false}) {
    final t = posFor(deedsDone);
    if (snap || t < worldX - 0.5) {
      worldX = t;
      targetX = t;
      state = GuddiState.idle;
      _stateTime = 0;
      arrivedStop = _stopIndexAt(t);
      // stops already behind or under us count as celebrated, so loading a user does not replay them
      celebrated
        ..clear()
        ..addAll([for (var i = 0; i < thresholds.length; i++) if (stopX(i) <= t + 0.5) i]);
      return;
    }
    targetX = t;
  }

  void _go(GuddiState s) {
    state = s;
    _stateTime = 0;
  }

  /// A new deed started while holding the celebration pose: return to idle first.
  bool get wantsToMove => targetX > worldX + 0.5;

  /// Called when the clip for the current one-shot state has finished playing.
  void clipFinished() {
    switch (state) {
      case GuddiState.walkStart:
        _go(GuddiState.walking);
        break;
      case GuddiState.walkStop:
        worldX = targetX;
        final i = _stopIndexAt(worldX);
        arrivedStop = i;
        if (i != null && !celebrated.contains(i)) {
          celebrated.add(i);
          _go(GuddiState.celebrate);
        } else {
          _go(GuddiState.idle);
        }
        break;
      case GuddiState.celebrate:
        _go(GuddiState.hold);
        break;
      case GuddiState.returning:
        _go(GuddiState.idle);
        break;
      default:
        break;
    }
  }

  /// Advance time. Returns true if worldX changed (the view should scroll).
  bool update(double dt) {
    _stateTime += dt;
    switch (state) {
      case GuddiState.idle:
        if (wantsToMove) {
          arrivedStop = null;
          _go(GuddiState.walkStart);
        }
        return false;
      case GuddiState.hold:
        if (wantsToMove) _go(GuddiState.returning);
        return false;
      case GuddiState.walkStart:
      case GuddiState.celebrate:
      case GuddiState.returning:
        return false;
      case GuddiState.walking:
        {
          final remaining = targetX - worldX;
          // start decelerating when the distance left equals what the stop clip will cover
          if (remaining <= walkSpeed * stopClipSeconds / 2) {
            _go(GuddiState.walkStop);
            return false;
          }
          worldX += walkSpeed * dt;
          return true;
        }
      case GuddiState.walkStop:
        {
          final left = targetX - worldX;
          final speed = walkSpeed * (1 - (_stateTime / stopClipSeconds).clamp(0.0, 1.0));
          final stepNow = speed * dt;
          worldX += stepNow > left ? left : stepNow;
          return stepNow > 0;
        }
    }
  }

  int? _stopIndexAt(double x) {
    for (var i = 0; i < thresholds.length; i++) {
      if ((stopX(i) - x).abs() < 1.0) return i;
    }
    return null;
  }
}
