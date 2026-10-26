import 'package:flutter/foundation.dart';
import 'journey_models.dart';

// The only door the journey-map screen uses to get data. SupabaseJourneyRepository talks to the
// live backend; UatJourneyRepository (lib/uat) is seeded in memory with no network.
abstract class JourneyRepository {
  // Fires after anything the screen displays may have changed (progress, claims).
  Listenable get changes;

  Future<JourneyConfig> loadCampaign(String campaignId);
  Future<JourneyProgress> loadProgress(String campaignId);

  // Throws JourneyException with the server's message on any refusal.
  Future<ClaimOutcome> claimStop(String stopId, int pickedIndex);

  // Called after a claim that may have changed the user's points; real impl reloads the profile.
  Future<void> refreshAfterClaim();
}
