import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';

// New screen — didn't exist before this pass. Verifies the 6-digit code sent by LoginScreen.
// On success, the caller (RootScreen) is responsible for checking whether a profiles row
// already exists for this user (returning user → Home) or not (new user → Profile Setup).
class OtpVerifyScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final VoidCallback onBack;
  const OtpVerifyScreen({super.key, required this.email, required this.onVerified, required this.onBack});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final codeController = TextEditingController();
  bool verifying = false;
  bool resending = false;
  String? error;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      setState(() => error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(email: widget.email, token: code, type: OtpType.email);
      if (mounted) widget.onVerified();
    } catch (e) {
      if (mounted) setState(() => error = 'That code didn\'t work — it may be wrong or expired. Try again or request a new one.');
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => resending = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: widget.email, shouldCreateUser: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not resend — try again in a moment.')));
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back, size: 16, color: AppColors.textSoft),
                const SizedBox(width: 6),
                Text('Back', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Check your email', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to ${widget.email}. Enter it below — it expires after a short while.',
              style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.5),
            ),
            const SizedBox(height: 22),
            LabeledTextField(
              label: 'Code',
              hint: '000000',
              controller: codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              errorText: error,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: verifying ? null : _verify,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: verifying ? AppColors.oliveCard : AppColors.gold, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(
                  verifying ? 'Verifying…' : 'Verify and continue',
                  style: AppFonts.fraunces(size: 15, weight: FontWeight.w600, color: verifying ? AppColors.textSoft : AppColors.inkOnGold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: resending ? null : _resend,
                child: Text(
                  resending ? 'Sending…' : "Didn't get it? Resend code",
                  style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
