import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/terms_sheet.dart';

// Real email OTP sign-in — the only sign-in method for MVP. Google Sign-In was removed
// (previously just a non-functional mock button) since it's not needed given this app isn't
// distributed via Play Store for this release; email-only is sufficient for MVP scope.
class LoginScreen extends StatefulWidget {
  final void Function(String email) onCodeSent;
  const LoginScreen({super.key, required this.onCodeSent});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  bool sending = false;
  String? error;
  bool agreedToTerms = false; // new — real, explicit acknowledgment required before signup

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    // New — real, required check, not just implied by continuing. Matches the T&Cs document's
    // own "By selecting I Agree..." language directly.
    if (!agreedToTerms) {
      setState(() => error = 'Please agree to the Terms & Conditions to continue.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      // shouldCreateUser: true — this same flow handles both brand-new signups and returning
      // users, matching "one screen either way" from the original design intent.
      await Supabase.instance.client.auth.signInWithOtp(email: email, shouldCreateUser: true);
      if (mounted) widget.onCodeSent(email);
    } on AuthException catch (e) {
      // Supabase's rate limit (roughly one request per ~11-60 seconds per email, to stop spam)
      // was previously shown as a generic "check your connection" message, which is actively
      // wrong — nothing about the connection was the problem. This gives the real reason.
      final isRateLimit = e.statusCode == '429' || e.message.toLowerCase().contains('rate_limit') || e.message.toLowerCase().contains('security purposes');
      if (mounted) {
        setState(() => error = isRateLimit
            ? 'You just requested a code — wait a few seconds before trying again.'
            : 'Could not send the code: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not send the code. Check your connection and try again.\n\n${e.toString()}');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HeroBand hidden for the pilot, per the current direction — widget and its file are
        // untouched, just not shown here. Add the Padding/HeroBand pair back to restore it.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Real fix here: this logo was genuinely dropped somewhere along the way and
                // never restored — confirmed there was no image reference here at all, just the
                // text. Sized compact, sitting directly above the wordmark, matching "top left."
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/logo.jpeg', width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                Text('Acha Karo', style: AppFonts.fraunces(size: 19, weight: FontWeight.w700, color: AppColors.gold)),
                const SizedBox(height: 2),
                Text('DO GOOD, GET SEEN', style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
                const SizedBox(height: 14),
                Text('Do something good. Get seen for it.', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  'Log small acts of civic good — clear litter, feed a stray, water a plant — earn points, and climb the weekly board.',
                  style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.5),
                ),
                const SizedBox(height: 22),
                LabeledTextField(
                  label: 'Email address',
                  hint: 'you@email.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  errorText: error,
                ),
                const SizedBox(height: 16),
                // New — real, explicit acknowledgment, replacing the old "just informational
                // text" approach with an actual required checkbox, per direction. Built with a
                // plain GestureDetector around just the link text rather than
                // RichText+TapGestureRecognizer — avoids both an extra import and the real
                // lifecycle-management risk of creating a new recognizer inline on every build.
                GestureDetector(
                  onTap: () => setState(() => agreedToTerms = !agreedToTerms),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Checkbox(
                      value: agreedToTerms,
                      onChanged: (v) => setState(() => agreedToTerms = v ?? false),
                      activeColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.textSoft),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Wrap(children: [
                          Text('I have read and agree to the ', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.5)),
                          GestureDetector(
                            onTap: () => showTermsAndConditions(context),
                            child: Text('Terms & Conditions', style: AppFonts.inter(size: 11.5, color: AppColors.gold, weight: FontWeight.w700).copyWith(decoration: TextDecoration.underline)),
                          ),
                          Text('.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _PrimaryButton(label: sending ? 'Sending…' : 'Send code', onTap: sending ? null : _sendCode),
                const SizedBox(height: 10),
                Text(
                  "We'll email you a 6-digit code — no password needed.",
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(size: 11, color: AppColors.textSoft),
                ),
                const SizedBox(height: 20),
                Text(
                  'By continuing, you agree to keep it honest — false submissions affect your standing.',
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: enabled ? AppColors.gold : AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text(label, style: AppFonts.fraunces(size: 15, weight: FontWeight.w600, color: enabled ? AppColors.inkOnGold : AppColors.textSoft)),
      ),
    );
  }
}
