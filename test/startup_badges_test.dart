import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/data/badges.dart';
import 'package:acha_karo/state/app_state.dart';

// Advisor badge vs the background load: feedback arrives after Home renders (wave 2), so until it
// has loaded a held Advisor badge must be kept, not dropped on every cold start.

void main() {
  final advisor = badgeDefs.firstWhere((b) => b.id == 'advisor');

  FeedbackEntry fb() => FeedbackEntry(stars: 5, text: 'x', day: 1);

  test('feedback not loaded yet: a held Advisor badge stays', () {
    final s = AppState()..user.badges = ['advisor'];
    expect(advisor.check(s), isTrue);
  });

  test('feedback not loaded yet: Advisor is not newly granted', () {
    final s = AppState();
    expect(advisor.check(s), isFalse);
  });

  test('once loaded, the real count decides', () {
    final s = AppState()
      ..user.badges = ['advisor']
      ..feedbackLoaded = true
      ..feedback = [fb(), fb()];
    expect(advisor.check(s), isFalse);
    s.feedback = [fb(), fb(), fb()];
    expect(advisor.check(s), isTrue);
  });

  test('sign-out resets it, so the next account starts unloaded', () {
    final s = AppState()..feedbackLoaded = true;
    // resetLocalState() calls notifyListeners() only — no Supabase access.
    s.resetLocalState();
    expect(s.feedbackLoaded, isFalse);
  });
}
