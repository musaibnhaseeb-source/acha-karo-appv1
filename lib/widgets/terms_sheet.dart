import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// App Terms of Use — the same copy as the website's Terms (v3, approved by Musa 2026-09-25;
// source: Marketing/terms-faq-draft.md "TERMS OF USE" + "URDU SUMMARY"), worded for the app
// ("on our Help page" instead of "above"). Keep the two in sync. Campaign-specific terms are
// separate (remote_config termsAndConditions) and unaffected. Structured as data (heading +
// paragraphs/bullets) so it's easy to check section-by-section against the source.
class _Section {
  final String heading;
  final List<String> paragraphs; // plain paragraphs
  final List<String> bullets; // rendered as a bullet list, after the paragraphs
  const _Section(this.heading, {this.paragraphs = const [], this.bullets = const []});
}

// "Last updated" = date of the latest Terms change (v1.3.1: optional location, NGO totals wording,
// review time; approved by Musa 2026-09-30). Keep in sync with the website Terms.
const _lastUpdated = '30 September 2026';
const kHelpContactUrl = 'https://achakaro.vercel.app/help.html#contact';

const List<_Section> _sections = [
  _Section('1. What Acha Karo is', paragraphs: [
    'Acha Karo is a free app that encourages everyday acha kaam across Pakistan. You do an acha kaam, share a photo, earn points and badges, and see how your city is doing. By using the app, you agree to these terms.',
  ]),
  _Section('2. Who can use it', paragraphs: [
    "You must be 14 or older. One account per person. If you're under 18, please use Acha Karo with a parent or guardian's knowledge. Keep your login private, because you're responsible for what happens on your account.",
  ]),
  _Section('3. Points', bullets: [
    'Acha Karo points are in-app points only. They have no cash value, and no purchase is needed.',
    "They can't be sold, exchanged, transferred or cashed out.",
    'We may correct or remove points that were given by mistake or earned by breaking these terms.',
    "Bonus points in any campaign follow that campaign's own rules page.",
  ]),
  _Section('4. Your acha kaam submissions', bullets: [
    'Only submit acha kaam you really did, with photos you took yourself.',
    "Photograph the acha kaam, not the person. Never show a child's face, and don't show anyone's private details.",
    "By submitting, you let Acha Karo store your photo so we can check it. Sharing your location is optional: we ask before each acha kaam, it's approximate (about 100 m), and only you and our moderators can see it. We'll only post your photo on social media with your permission.",
    "Most acha kaam are approved automatically. Some are checked by our team, usually within 48 hours; when it's busy it can take up to 2 more days. We can review, approve or reject any acha kaam, and our decision is final.",
  ]),
  _Section("5. What's not allowed", paragraphs: [
    'Fake, copied or repeated submissions; multiple accounts; gaming the leaderboard; harassing other users; anything illegal, hateful or sexual; tampering with the app or pretending to be Acha Karo. We can suspend or remove accounts that break these rules.',
  ]),
  _Section('6. Your data', bullets: [
    'We collect only what the app needs (see Privacy on our Help page).',
    'Other users see your first name and last initial, city, points and badge count. A nickname is fine.',
    'We may share anonymous, area-level totals with partner organisations such as NGOs — for example, how many acha kaam were done in a neighbourhood. This never includes names, emails, phone numbers, photos or exact locations, and an area is only included when at least 5 different members were active there.',
    "We don't sell your data or show ads.",
    'If you delete your account, we delete it within 30 days, along with your acha kaam, photos and locations.',
    'We keep contact form messages for 3 months.',
  ]),
  _Section('7. Installing the app', paragraphs: [
    "Download Acha Karo only from achakaro.vercel.app or the link in our official social media bios. We're not responsible for copies downloaded from anywhere else.",
  ]),
  _Section('8. The app is still growing', paragraphs: [
    "Acha Karo is new and still in a pilot phase. Features may change, and things may occasionally break. We'll fix problems as quickly as we can, but the app is provided as it is.",
  ]),
  _Section('9. Changes', paragraphs: [
    "If we change these terms, we'll update them here and the date at the top. If you keep using the app after a change, you accept the new terms.",
  ]),
  _Section('10. Not affiliated', paragraphs: [
    'Acha Karo is not sponsored, endorsed or administered by, or associated with, Instagram, Meta, TikTok or Google.',
  ]),
  _Section('11. Governing law', paragraphs: [
    'These terms are governed by the laws of Pakistan.',
  ]),
  _Section('12. Contact', paragraphs: [
    'Questions, complaints or concerns? Use the contact form on our Help page.',
  ]),
];

// Urdu summary (خلاصہ) — same approved copy as the website.
const List<String> _urduSummary = [
  'اچھا کرو ایک مفت ایپ ہے۔ اچھا کام کریں، تصویر لیں، اور پوائنٹس اور بیجز حاصل کیجیے۔ عمر 14 سال یا اس سے زیادہ، ایک شخص ایک اکاؤنٹ۔ اگر آپ کی عمر 18 سال سے کم ہے تو براہِ کرم اچھا کرو اپنے والدین یا سرپرست کے علم میں رکھ کر استعمال کیجیے۔',
  'پوائنٹس صرف ایپ کے اندر ہیں۔ ان کی کوئی نقد قیمت نہیں، اور کچھ خریدنے کی ضرورت نہیں۔',
  'زیادہ تر اچھے کام فوراً منظور ہو جاتے ہیں۔ کچھ ہماری ٹیم چیک کرتی ہے، عموماً 48 گھنٹوں کے اندر؛ زیادہ رش ہو تو 2 دن مزید لگ سکتے ہیں۔',
  'آپ کا درجہ (چوزہ سے شاہین تک) بیجز کی تعداد سے طے ہوتا ہے۔',
  'دوسرے صارفین آپ کا پہلا نام اور آخری نام کا پہلا حرف، شہر، پوائنٹس اور بیجز دیکھ سکتے ہیں۔ آپ فرضی نام بھی استعمال کر سکتے ہیں۔',
  'اچھے کام کی تصویر صرف آپ اور ہماری ٹیم دیکھتی ہے۔ لوکیشن شیئر کرنا آپ کی مرضی ہے: ہر اچھے کام سے پہلے پوچھا جاتا ہے، یہ تقریباً 100 میٹر تک درست ہوتی ہے، اور اسے صرف آپ اور ہمارے ماڈریٹرز دیکھ سکتے ہیں۔',
  'ہم پارٹنر اداروں، جیسے این جی اوز، کے ساتھ علاقے کی سطح کے گمنام اعداد و شمار شیئر کر سکتے ہیں، مثلاً کسی محلے میں کتنے اچھے کام ہوئے۔ اس میں کبھی نام، ای میل، فون نمبر، تصویریں یا درست لوکیشن شامل نہیں ہوتی، اور کوئی علاقہ صرف تب شامل ہوتا ہے جب وہاں کم از کم 5 مختلف ممبرز ایکٹو رہے ہوں۔',
  'آپ کی تصویر سوشل میڈیا پر صرف آپ کی اجازت سے لگائی جائے گی۔',
  'اکاؤنٹ ڈیلیٹ کرنے کے لیے: ایپ میں Settings ← Delete account۔ 30 دن کے اندر اکاؤنٹ، اچھے کام، تصویریں اور لوکیشنز سب ڈیلیٹ کر دیے جاتے ہیں۔',
  'رابطہ فارم کے پیغامات 3 ماہ تک رکھے جاتے ہیں۔',
  'ایپ صرف achakaro.vercel.app یا ہمارے آفیشل سوشل میڈیا بائیو کے لنک سے ڈاؤن لوڈ کیجیے۔',
  'یہ شرائط پاکستان کے قوانین کے تحت ہیں۔ کسی بھی فرق کی صورت میں انگریزی شرائط لاگو ہوں گی۔',
];

Future<void> _openContact() async {
  try {
    await launchUrl(Uri.parse(kHelpContactUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser available — nothing else to do.
  }
}

void showTermsAndConditions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Expanded(child: Text('Terms of Use', style: AppFonts.fraunces(size: 17, weight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.close, color: AppColors.textSoft), onPressed: () => Navigator.of(ctx).pop()),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last updated: $_lastUpdated', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                  const SizedBox(height: 16),
                  for (final s in _sections) ...[
                    Text(s.heading, style: AppFonts.fraunces(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    for (final p in s.paragraphs) ...[
                      Text(p, style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.6)),
                      const SizedBox(height: 6),
                    ],
                    for (final b in s.bullets)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('•  ', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                          Expanded(child: Text(b, style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.5))),
                        ]),
                      ),
                    const SizedBox(height: 14),
                  ],
                  // Contact us — opens the Help page's contact form in the browser.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openContact,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.gold.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.gold),
                      label: Text('Contact us', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('خلاصہ', style: AppFonts.nastaliq(size: 18, color: AppColors.text)),
                      const SizedBox(height: 4),
                      for (final line in _urduSummary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('•  $line', style: AppFonts.nastaliq(size: 13, color: AppColors.textSoft)),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
