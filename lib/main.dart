import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verify_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/main_tab_screen.dart';
import 'screens/welcome_animation_screen.dart';
import 'widgets/animated_wallpaper.dart';
import 'utils/notifications.dart';
import 'utils/daily_reminder.dart';
import 'widgets/update_available_dialog.dart';
import 'widgets/guddi_loading.dart';
import 'supabase_config.dart';

// App entry point — connects to Supabase (all real data lives there, read/written via AppState),
// then shows RootScreen, which routes between login, profile setup and the main app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  // Real fix attempt #2 for the black-unused-screen-area issue. The earlier widget-tree fix
  // (a Stack with the gradient as a Positioned.fill layer, applied across 10 screens) did NOT
  // resolve it on real-device testing — a strong signal the actual cause was misdiagnosed the
  // first time. That fix stays in place (it's still correct defensively), but this is the real
  // likely culprit: Android's own system navigation bar renders plain black by default,
  // regardless of what the app itself draws — this makes it match the app's dark background
  // instead, which is a system-chrome configuration issue, not a Flutter layout one.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: AppColors.bg1,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AchaKaroApp());
}

class AchaKaroApp extends StatelessWidget {
  const AchaKaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Acha Karo',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // App-wide text scale from Settings (A-/A/A+) applied here, once, rather than threading
        // a scale factor through every screen individually.
        //
        // New — genuine, guaranteed safety net for the black-gap background issue, rather than
        // continuing to chase its exact per-screen cause. Every screen intentionally sets its
        // own Scaffold to Colors.transparent so its custom gradient can show through — which
        // means the theme's scaffoldBackgroundColor (already correctly set to AppColors.bg1)
        // never actually gets a chance to act as a fallback, since every screen opts out of it.
        // This Container sits underneath the ENTIRE app's widget tree instead — genuinely
        // guaranteed to be there regardless of what any individual screen does or doesn't
        // render correctly.
        builder: (context, child) => Container(
          color: AppColors.bg1,
          child: Consumer<AppState>(
            builder: (context, state, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(state.textScaleFactor)),
              child: child!,
            ),
          ),
        ),
        home: const RootScreen(),
      ),
    );
  }
}

enum RootScreenState { checkingSession, login, otpVerify, setup, welcome, app }

// Ported flow: login -> OTP verify -> (existing user: straight to app) or (new user: setup ->
// welcome -> app). Session check on startup means a returning user who never logged out skips
// Login entirely — matches how Supabase Auth actually behaves (stays signed in until you
// explicitly log out), confirmed as the intended behavior earlier in this project.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

// Real architectural gap addressed here — the app only ever fetched data once, at login, with
// nothing pushing live updates while it was open. WidgetsBindingObserver lets this refresh
// automatically whenever the app comes back to the foreground (switching apps and back, not
// just a full restart) — paired with pull-to-refresh on Home (see home_screen.dart) for
// explicit, on-demand refreshing too. Doesn't require real-time subscriptions to meaningfully
// close this gap — just re-running the same load that already happens at login.
class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  RootScreenState screen = RootScreenState.checkingSession;
  String? pendingEmail; // set once a code has been sent, needed by OtpVerifyScreen
  StreamSubscription<AuthState>? _authSub;
  bool _updateDialogShown = false; // guards the update popup from showing more than once per state change

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Doesn't depend on auth state (campaigns/app_config are publicly readable) — loads
    // regardless of whether this ends up being a login or a returning-session skip.
    context.read<AppState>().loadRemoteConfig();
    context.read<AppState>().loadTextScale(); // device-local A−/A/A+ choice
    // System notifications are set up here but NEVER prompt at start — the permission is only
    // asked in context (after the onboarding tour or a deed; see DailyReminder.maybeAsk).
    initNotifications();
    _checkExistingSession();

    // Real gap fixed here: there was no logout anywhere in the app at all. Listening centrally
    // for the sign-out event (rather than having Settings manually coordinate this) means ANY
    // sign-out — from Settings now, or anywhere else later — correctly resets the whole app back
    // to Login and pops back out of wherever the person was, not just wherever the button lives.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        DailyReminder.cancelAll(); // no "Guddi is waiting" nudges for a signed-out phone
        context.read<AppState>().resetLocalState();
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() {
          screen = RootScreenState.login;
          pendingEmail = null;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      // Reinforced here too, defensively — some Android/Flutter combinations can reset system
      // UI styling on resume, so this makes sure the nav bar color fix from main() holds even
      // after backgrounding and returning to the app.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: AppColors.bg1,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      );
    }
    // Only refresh once actually signed in and past setup — no point re-fetching a profile that
    // doesn't exist yet, or interrupting the login/OTP flow.
    if (appState == AppLifecycleState.resumed && screen == RootScreenState.app) {
      // Same gap as Home's pull-to-refresh, fixed the same way — loadRemoteConfig() (campaigns)
      // needs to actually run here too, not just tryLoadExistingProfile(), or a disabled
      // campaign would keep showing after resuming from background just like it did before.
      final appStateObj = context.read<AppState>();
      // Every app open also rebuilds the daily-reminder schedule (which resets its back-off).
      appStateObj.tryLoadExistingProfile().then(
        (found) {
          if (found) DailyReminder.reschedule(loggedToday: appStateObj.loggedDeedToday);
        },
        onError: (_) {}, // offline resume — keep what's on screen
      );
      appStateObj.loadRemoteConfig();
    }
  }

  Future<void> _checkExistingSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() => screen = RootScreenState.login);
      return;
    }
    final found = await context.read<AppState>().tryLoadExistingProfile();
    if (!mounted) return;
    // Signed in but somehow no profile row (shouldn't normally happen) — fall back to Setup
    // rather than getting stuck.
    setState(() => screen = found ? RootScreenState.app : RootScreenState.setup);
    // New — real update check, placed here specifically rather than earlier in initState(),
    // since a genuine, confirmed session is needed before this can do anything meaningful.
    if (found) {
      context.read<AppState>().checkForUpdate();
      context.read<AppState>().loadEquippedSkin();
      DailyReminder.reschedule(loggedToday: context.read<AppState>().loggedDeedToday);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // New — real update popup, shown once when a genuine, active update this user hasn't
    // acknowledged yet is present. Guarded so it only ever triggers once per state change,
    // not on every rebuild.
    if (state.pendingUpdate != null && !_updateDialogShown) {
      _updateDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(context: context, barrierDismissible: false, builder: (_) => UpdateAvailableDialog(update: state.pendingUpdate!))
              .then((_) => _updateDialogShown = false);
        }
      });
    }

    return Scaffold(
      // Real fix here: the background now sits OUTSIDE SafeArea, not inside it — the previous
      // structure meant an explicit full MediaQuery size would have been positioned relative to
      // SafeArea's own reduced bounds, not the actual full screen, working against the fix
      // rather than completing it. SafeArea now wraps only the real content underneath.
      body: Stack(
        // Real, genuine root-cause fix: Stack defaults to StackFit.loose, meaning it sizes
        // itself to its non-Positioned child (SafeArea), which in turn sizes to its OWN content
        // rather than filling available space. Every previous attempt only ever changed the
        // background widget itself, never addressed this — the Positioned background was
        // always being clipped down to match the Stack's own, content-sized bounds, regardless
        // of what explicit size it was given. This forces the Stack itself to fill available
        // space unconditionally, which is the actual fix.
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[state.wallpaperSwatchIndex]),
          ),
          SafeArea(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (screen) {
      case RootScreenState.checkingSession:
        // Guddi instead of a spinner. A saved session means a returning user; without one this
        // state is left almost immediately for Login, so firstOpen is rarely on screen.
        return GuddiLoading(returning: Supabase.instance.client.auth.currentSession != null);
      case RootScreenState.login:
        return LoginScreen(
          onCodeSent: (email) => setState(() {
            pendingEmail = email;
            screen = RootScreenState.otpVerify;
          }),
        );
      case RootScreenState.otpVerify:
        return OtpVerifyScreen(
          email: pendingEmail!,
          onBack: () => setState(() => screen = RootScreenState.login),
          onVerified: () async {
            final found = await context.read<AppState>().tryLoadExistingProfile();
            if (!mounted) return;
            setState(() => screen = found ? RootScreenState.app : RootScreenState.setup);
            if (found) {
              context.read<AppState>().checkForUpdate();
              context.read<AppState>().loadEquippedSkin();
              DailyReminder.reschedule(loggedToday: context.read<AppState>().loggedDeedToday);
            }
          },
        );
      case RootScreenState.setup:
        return ProfileSetupScreen(
          onComplete: ({required name, required gender, required dob, required city, phone, avatarFile}) async {
            final appState = context.read<AppState>();
            appState.completeSetup(name: name, gender: gender, dob: dob, city: city, phone: phone, avatarFile: avatarFile);
            // Real write now — creates the actual profiles row in Supabase to match. Real bug
            // fixed here: this had no error checking at all, so a failure here was completely
            // silent — Continue would look enabled and do nothing when tapped, no visible error
            // anywhere. Without a real profile row, there's nothing for the rest of setup to
            // actually attach to, so this genuinely should stop the flow.
            final profileError = await appState.createProfileInSupabase();
            if (profileError != null && mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.bg2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Text('Could not finish setup', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
                  content: Text(profileError, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.gold))),
                  ],
                ),
              );
              return; // Stops here deliberately — see comment above.
            }
            // Brand-new account — Home shows the full 4-step Guddi tour, not the returning version.
            appState.justCompletedSetup = true;
            if (mounted) setState(() => screen = RootScreenState.welcome);
          },
        );
      case RootScreenState.welcome:
        return WelcomeAnimationScreen(
          name: context.read<AppState>().user.name.split(' ').first,
          onDone: () => setState(() => screen = RootScreenState.app),
        );
      case RootScreenState.app:
        // Profile is a real tab now, not hidden — brought back per direction as "not a
        // regression, a necessity." Board/Achievements stays parked, per explicit instruction.
        return const MainTabScreen();
    }
  }
}
