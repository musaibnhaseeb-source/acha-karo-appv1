import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/invite_response.dart';

// Invite Accept / Decline: the RPC call shape must match the live function exactly
// (respond_to_invite(p_invite_id, p_response)), and only the right types get buttons.

void main() {
  test('RPC name and params match respond_to_invite(p_invite_id, p_response)', () {
    expect(respondToInviteRpc, 'respond_to_invite');
    expect(respondToInviteParams('inv-1', accept: true), {'p_invite_id': 'inv-1', 'p_response': 'accepted'});
    expect(respondToInviteParams('inv-1', accept: false), {'p_invite_id': 'inv-1', 'p_response': 'declined'});
  });

  test('karocast, town_voice, service_call and co_create are answered in the app', () {
    for (final t in ['karocast', 'town_voice', 'service_call', 'co_create']) {
      expect(inviteNeedsAnswer(t, null), isTrue, reason: t);
      expect(inviteNeedsAnswer(t, 'accepted'), isFalse, reason: '$t already answered');
      expect(inviteNeedsAnswer(t, 'declined'), isFalse, reason: '$t already answered');
    }
    expect(inviteNeedsAnswer('something_new', null), isFalse);
  });

  test('copy: no raw errors, no "winner", no bare karein', () {
    const all = [
      InviteCopy.accept, InviteCopy.decline, InviteCopy.accepted, InviteCopy.declined, InviteCopy.declineTitle,
      InviteCopy.declineBody, InviteCopy.guardianNote, InviteCopy.sendFailed, InviteCopy.loadFailed, InviteCopy.retry,
    ];
    for (final s in all) {
      expect(s.toLowerCase(), isNot(contains('winner')));
      expect(s.toLowerCase(), isNot(contains('karein')));
      expect(s, isNot(contains(r'$')));
    }
    expect(InviteCopy.accepted, "Accepted ✓ — we'll email you the details");
    expect(InviteCopy.guardianNote, "If you're under 18, a parent or guardian must agree before you accept.");
    expect(InviteCopy.sendFailed, "Couldn't send your answer — try again");
  });
}
