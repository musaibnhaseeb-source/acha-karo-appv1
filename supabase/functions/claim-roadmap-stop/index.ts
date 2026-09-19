// claim-roadmap-stop — the first Edge Function in this project. Genuinely new territory:
// different language (TypeScript/Deno, not Dart or SQL), different deployment mechanism (CLI,
// not the SQL Editor), different execution environment entirely. Worth extra care on first
// deploy, same as every other "first" in this build (the release keystore, core library
// desugaring, etc.).
//
// This is what makes roadmap_claims safe to have had NO client insert policy at all — the app
// itself never decides who wins. This function does, running on Supabase's own servers, using
// the service-role key (elevated access, bypasses RLS entirely) to check things the client could
// otherwise lie about:
//   1. Who the caller genuinely is (their real, verified session — not a claimed user ID)
//   2. Whether they've actually reached this stop (real deed count in the database, not
//      whatever the app's local state believes)
//   3. Whether they've already claimed it before (the database's own unique constraint backs
//      this up too, as a second layer)
//   4. The actual win/lose outcome — real server-side randomness, decided fresh, only after all
//      of the above checks pass
//
// The client sends which box it tapped; this function generates the REAL winning set internally
// and checks whether that tap was a winner, then returns ONLY that outcome (won: true/false,
// plus prize info) — not the full winning set. Deliberate, not an oversight: if the full set of
// winning positions were ever returned, it would exist somewhere accessible on the device the
// moment the sheet opens, even for boxes never tapped — undermining the whole point of deciding
// this server-side. The other 8 boxes genuinely have no answer to reveal, since nothing was
// ever decided for them.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Not authenticated." }), { status: 401, headers: corsHeaders });
    }

    // Regular client, scoped to the caller's own session — used only to confirm who they
    // genuinely are, not for any of the trusted checks below.
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Not authenticated." }), { status: 401, headers: corsHeaders });
    }

    const { stop_id, picked_index } = await req.json();
    if (!stop_id || picked_index === undefined || picked_index === null) {
      return new Response(JSON.stringify({ error: "Missing stop_id or picked_index." }), { status: 400, headers: corsHeaders });
    }

    // Service-role client — elevated access for the trusted checks and the actual write.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // 1. Real stop configuration — not anything the client sent.
    const { data: stop, error: stopError } = await supabaseAdmin
      .from("roadmap_stops")
      .select("*")
      .eq("id", stop_id)
      .single();
    if (stopError || !stop) {
      return new Response(JSON.stringify({ error: "Stop not found." }), { status: 404, headers: corsHeaders });
    }

    if (picked_index < 0 || picked_index >= stop.total_boxes) {
      return new Response(JSON.stringify({ error: "Invalid box." }), { status: 400, headers: corsHeaders });
    }

    // 2. Real progress check — actual approved deed count for this campaign, not whatever the
    // app's local state claims.
    const { count, error: countError } = await supabaseAdmin
      .from("deeds")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("status", "approved")
      .eq("campaign_id", stop.campaign_id);
    if (countError) {
      return new Response(JSON.stringify({ error: "Could not verify your progress." }), { status: 500, headers: corsHeaders });
    }
    if ((count ?? 0) < stop.threshold) {
      return new Response(JSON.stringify({ error: "You have not reached this stop yet." }), { status: 403, headers: corsHeaders });
    }

    // 3. Not already claimed — checked here, and backed up by the table's own unique
    // constraint as a second layer in case of a genuine race.
    const { data: existing } = await supabaseAdmin
      .from("roadmap_claims")
      .select("id")
      .eq("user_id", user.id)
      .eq("stop_id", stop_id)
      .maybeSingle();
    if (existing) {
      return new Response(JSON.stringify({ error: "You have already claimed this stop." }), { status: 409, headers: corsHeaders });
    }

    // 4. Real randomness, decided here, only now that every check above has passed — genuinely
    // unknown to the client (or anyone inspecting the app) until this response comes back.
    const allIndices = Array.from({ length: stop.total_boxes }, (_, i) => i);
    for (let i = allIndices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [allIndices[i], allIndices[j]] = [allIndices[j], allIndices[i]];
    }
    const winningIndices = allIndices.slice(0, stop.winning_boxes);
    const won = winningIndices.includes(picked_index);

    // 5. Record the outcome.
    const { error: insertError } = await supabaseAdmin
      .from("roadmap_claims")
      .insert({ user_id: user.id, stop_id: stop_id, won, box_index: picked_index });
    if (insertError) {
      return new Response(JSON.stringify({ error: "Could not record your claim." }), { status: 500, headers: corsHeaders });
    }

    // 6. New — reward_mode branches here. 'standard' (Stop 1, Stop 3) keeps the existing
    // behavior exactly as before: win shows the prize, lose shows nothing, no automatic
    // granting of anything beyond the claim record itself. 'guaranteed_with_discount' (Stop 2)
    // is genuinely different: every tap results in something real — the winning card grants
    // the skin free, any other card grants a discount instead. Never "you got nothing."
    if (stop.reward_mode === "guaranteed_with_discount" && stop.skin_id) {
      if (won) {
        const { error: skinError } = await supabaseAdmin
          .from("user_vehicle_skins")
          .insert({ user_id: user.id, skin_id: stop.skin_id });
        if (skinError) {
          return new Response(JSON.stringify({ error: "Could not grant your skin." }), { status: 500, headers: corsHeaders });
        }
        return new Response(
          JSON.stringify({ won: true, outcome: "free_skin", skin_id: stop.skin_id, prize_name: stop.prize_name, prize_icon: stop.prize_icon }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      } else {
        const { error: discountError } = await supabaseAdmin
          .from("user_skin_discounts")
          // Real fix here: user_skin_discounts has a composite primary key (user_id, skin_id),
          // not a single id column — upsert() needs to be told this explicitly via onConflict,
          // or it can fail against a table shaped this way.
          .upsert({ user_id: user.id, skin_id: stop.skin_id, discount_percent: stop.discount_percent }, { onConflict: "user_id,skin_id" });
        if (discountError) {
          return new Response(JSON.stringify({ error: "Could not grant your discount." }), { status: 500, headers: corsHeaders });
        }
        return new Response(
          JSON.stringify({ won: false, outcome: "discount", skin_id: stop.skin_id, discount_percent: stop.discount_percent }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    // Real bug fixed here — a genuinely serious one: this previously never checked whether
    // either the read or the write actually succeeded. If the update silently failed for any
    // reason, the function would still return "success, +points" to the app, which would then
    // show a real congratulations message for points that were never actually credited — exactly
    // matching a real report of this happening. Now both steps are checked, and a real failure
    // here fails the whole claim with a visible error instead of silently claiming success.
    if (won && stop.prize_points) {
      const { data: profile, error: profileReadError } = await supabaseAdmin.from("profiles").select("points").eq("id", user.id).single();
      if (profileReadError || !profile) {
        return new Response(JSON.stringify({ error: "Could not read your profile to credit points." }), { status: 500, headers: corsHeaders });
      }
      const { error: pointsUpdateError } = await supabaseAdmin.from("profiles").update({ points: profile.points + stop.prize_points }).eq("id", user.id);
      if (pointsUpdateError) {
        return new Response(JSON.stringify({ error: "Could not credit your points: " + pointsUpdateError.message }), { status: 500, headers: corsHeaders });
      }
    }

    // Standard behavior otherwise unchanged.
    return new Response(
      JSON.stringify({
        won,
        outcome: won ? "prize" : "none",
        prize_name: stop.prize_name,
        prize_icon: stop.prize_icon,
        prize_points: won ? stop.prize_points : null,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message ?? "Something went wrong." }), { status: 500, headers: corsHeaders });
  }
});