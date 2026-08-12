import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verify_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_animation_screen.dart';
import 'widgets/animated_wallpaper.dart';
import 'supabase_config.dart';

// This connects the app to Supabase — but only the CONNECTION. Nothing in AppState reads or
// writes to it yet; that's the next, much bigger step (designing tables, then migrating each
// piece of app data). For now this just proves the app can reach your project at all.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
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
        builder: (context, child) => Consumer<AppState>(
          builder: (context, state, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(state.textScaleFactor)),
            child: child!,
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

class _RootScreenState extends State<RootScreen> {
  RootScreenState screen = RootScreenState.checkingSession;
  String? pendingEmail; // set once a code has been sent, needed by OtpVerifyScreen
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Doesn't depend on auth state (campaigns/app_config are publicly readable) — loads
    // regardless of whether this ends up being a login or a returning-session skip.
    context.read<AppState>().loadRemoteConfig();
    _checkExistingSession();

    // Real gap fixed here: there was no logout anywhere in the app at all. Listening centrally
    // for the sign-out event (rather than having Settings manually coordinate this) means ANY
    // sign-out — from Settings now, or anywhere else later — correctly resets the whole app back
    // to Login and pops back out of wherever the person was, not just wherever the button lives.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && mounted) {
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
    _authSub?.cancel();
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: AnimatedWallpaper(gradientColors: wallpaperSwatches[state.wallpaperSwatchIndex])),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (screen) {
      case RootScreenState.checkingSession:
        return const Center(child: CircularProgressIndicator(color: AppColors.gold));
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
          },
        );
      case RootScreenState.setup:
        return ProfileSetupScreen(
          onComplete: ({required name, required gender, required dob, required city, phone, avatarFile, inviteCode}) async {
            final appState = context.read<AppState>();
            appState.completeSetup(name: name, gender: gender, dob: dob, city: city, phone: phone, avatarFile: avatarFile);
            // Real write now — creates the actual profiles row in Supabase to match. If this
            // fails (e.g. no connection), local state still updated so the person isn't stuck;
            // the row just wouldn't exist remotely yet, worth a proper retry/error UI later.
            await appState.createProfileInSupabase();
            // Redeeming needs a real profile row to exist first (the friendship references it),
            // so this deliberately runs after createProfileInSupabase completes, not before.
            // Real bug fixed here: the error result was being completely discarded — if
            // redemption failed for ANY reason, there was no way to ever find out why. Now shown
            // directly, so the actual failure reason (if any) is visible instead of silent.
            if (inviteCode != null && inviteCode.isNotEmpty) {
              final error = await appState.redeemInviteCode(inviteCode);
              if (error != null && mounted) {
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bg2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: Text('Invite code', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
                    content: Text(error, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.gold))),
                    ],
                  ),
                );
              }
            }
            if (mounted) setState(() => screen = RootScreenState.welcome);
          },
        );
      case RootScreenState.welcome:
        return WelcomeAnimationScreen(
          name: context.read<AppState>().user.name.split(' ').first,
          onDone: () => setState(() => screen = RootScreenState.app),
        );
      case RootScreenState.app:
        // Simplified to Home only, per the current pilot direction — Board (Achievements) and
        // Profile are both hidden now, which left the nav bar with a single real destination.
        // Removing the nav bar entirely rather than keeping a 1-item bar that has nothing to
        // switch between. Neither BoardScreen nor ProfileScreen's code was touched — same
        // hide-don't-delete treatment as everything else this pass, both fully restorable by
        // adding them back to a nav structure whenever they're wanted again.
        return const HomeScreen();
    }
  }
}
