// Accept / Decline on invites. Users answer ONLY through the respond_to_invite RPC (it also sets
// seen=true, and refuses invites that aren't theirs or are already answered); a trigger blocks
// any other direct write to invites except `seen`. Kept here so the exact call shape is tested.

const respondToInviteRpc = 'respond_to_invite';

Map<String, dynamic> respondToInviteParams(String inviteId, {required bool accept}) => {
      'p_invite_id': inviteId,
      'p_response': accept ? 'accepted' : 'declined',
    };

// Invite types that are answered in the app (all four current types).
const answerableInviteTypes = {'karocast', 'town_voice', 'service_call', 'co_create'};

bool inviteNeedsAnswer(String inviteType, String? response) => answerableInviteTypes.contains(inviteType) && response == null;

class InviteCopy {
  static const accept = 'Accept';
  static const decline = 'Decline';
  static const accepted = "Accepted ✓ — we'll email you the details";
  static const declined = 'Declined';
  static const declineTitle = 'Decline this invite?';
  static const declineBody = "You won't be able to change your answer later.";
  static const declineConfirm = 'Decline';
  static const declineCancel = 'Keep it';
  static const guardianNote = "If you're under 18, a parent or guardian must agree before you accept.";
  static const sendFailed = "Couldn't send your answer — try again";
  static const loadFailed = "Couldn't load invites. Check your connection and try again.";
  static const retry = 'Try again';
}
