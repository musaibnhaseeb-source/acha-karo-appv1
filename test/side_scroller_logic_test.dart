import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/journey/side_scroller_logic.dart';

void main() {
  // stops at 2, 4 and 6 deeds -> world x 520, 1040, 1560
  SideScrollerLogic make({int start = 0}) => SideScrollerLogic(thresholds: const [2, 4, 6], startDeeds: start);

  // Plays the walk until she stands still; one-shot clips finish immediately (stop clip after its length).
  void settle(SideScrollerLogic l, {int maxSteps = 6000}) {
    for (var i = 0; i < maxSteps; i++) {
      l.update(1 / 60);
      if (l.state == GuddiState.walkStart) l.clipFinished();
      if (l.state == GuddiState.walkStop && l.stateTime >= l.stopClipSeconds) l.clipFinished();
      if (l.state == GuddiState.celebrate || l.state == GuddiState.returning) l.clipFinished();
      if ((l.state == GuddiState.idle || l.state == GuddiState.hold) && !l.wantsToMove) return;
    }
  }

  test('posFor matches the design: stops at (i+1)*step, linear between', () {
    final l = make();
    expect(l.posFor(0), 0);
    expect(l.posFor(1), 260);
    expect(l.posFor(2), 520);
    expect(l.posFor(3), 780);
    expect(l.posFor(4), 1040);
    expect(l.posFor(6), 1560);
    expect(l.posFor(99), 1560);
  });

  test('idle with no new progress stays idle', () {
    final l = make();
    for (var i = 0; i < 100; i++) {
      l.update(1 / 60);
    }
    expect(l.state, GuddiState.idle);
    expect(l.worldX, 0);
  });

  test('a new deed starts the walk: idle -> walkStart -> walking', () {
    final l = make();
    l.setProgress(1);
    l.update(1 / 60);
    expect(l.state, GuddiState.walkStart);
    l.clipFinished();
    expect(l.state, GuddiState.walking);
  });

  test('walks to a non-stop target and ends exactly there without celebrating', () {
    final l = make();
    l.setProgress(1);
    settle(l);
    expect(l.worldX, closeTo(260, 0.01));
    expect(l.state, GuddiState.idle);
    expect(l.arrivedStop, isNull);
    expect(l.celebrated, isEmpty);
  });

  test('arriving at a stop celebrates once, holds, and a new deed returns then walks on', () {
    final l = make();
    l.setProgress(2);
    settle(l);
    expect(l.state, GuddiState.hold);
    expect(l.arrivedStop, 0);
    expect(l.worldX, closeTo(520, 0.01));
    expect(l.celebrated, {0});
    // holds until the next deed
    for (var i = 0; i < 300; i++) {
      l.update(1 / 60);
    }
    expect(l.state, GuddiState.hold);
    l.setProgress(3);
    l.update(1 / 60);
    expect(l.state, GuddiState.returning);
    l.clipFinished();
    expect(l.state, GuddiState.idle);
    l.update(1 / 60);
    expect(l.state, GuddiState.walkStart);
    settle(l);
    expect(l.worldX, closeTo(780, 0.01));
    expect(l.state, GuddiState.idle);
  });

  test('multi-deed jump across a stop: she stops at the target only (set to 5 from 1)', () {
    final l = make(start: 1);
    l.setProgress(5);
    settle(l);
    expect(l.worldX, closeTo(l.posFor(5), 0.01));
  });

  test('never overshoots the target while decelerating', () {
    final l = make();
    l.setProgress(1);
    var maxX = 0.0;
    for (var i = 0; i < 3000; i++) {
      l.update(1 / 60);
      if (l.state == GuddiState.walkStart) l.clipFinished();
      if (l.state == GuddiState.walkStop && l.stateTime >= l.stopClipSeconds) l.clipFinished();
      if (l.worldX > maxX) maxX = l.worldX;
    }
    expect(maxX, lessThanOrEqualTo(260.0001));
  });

  test('going backwards (user switch / reset) snaps with no walking and marks passed stops celebrated', () {
    final l = make(start: 6);
    l.setProgress(2);
    expect(l.worldX, 520);
    expect(l.state, GuddiState.idle);
    expect(l.arrivedStop, 0);
    expect(l.celebrated, {0});
  });

  test('snap flag jumps forward too (UAT user switch to a more advanced user)', () {
    final l = make();
    l.setProgress(6, snap: true);
    expect(l.worldX, 1560);
    expect(l.state, GuddiState.idle);
    expect(l.celebrated, {0, 1, 2});
  });
}
