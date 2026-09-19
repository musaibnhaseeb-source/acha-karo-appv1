import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// New — the real, full T&Cs document, shown as a genuine popup rather than a separate screen or
// external link, per direction. Both "Today's date" placeholders in the source document replaced
// with the real, specified date (1 Sep 2026). Structured as data (heading + paragraphs/bullets)
// rendered programmatically, rather than hand-built Text widgets per section — reduces the real
// risk of a transcription slip somewhere in a document this long, and makes it easy to verify
// section-by-section against the source.
class _Section {
  final String heading;
  final List<String> paragraphs; // plain paragraphs
  final List<String> bullets; // rendered as a bullet list, after the paragraphs
  const _Section(this.heading, {this.paragraphs = const [], this.bullets = const []});
}

const _effectiveDate = '1 September 2026';

final List<_Section> _sections = [
  const _Section('1. About Acha Karo', paragraphs: [
    'Acha Karo is a digital platform designed to encourage positive actions, community participation, learning, challenges, campaigns and recognition.',
    'The platform may include points, badges, digital items, campaigns, challenges, leaderboards, rewards and opportunities to participate in content or community activities.',
  ]),
  const _Section('2. Eligibility and Minors', paragraphs: [
    'Users must provide accurate information when creating an account.',
    'Users under the age of 18 must use Acha Karo with the knowledge, permission and appropriate supervision of a parent or legal guardian.',
    'Parents or guardians are responsible for determining whether a particular activity, challenge, campaign or task is appropriate and safe for a minor.',
    'Acha Karo does not require or encourage minors to undertake activities that are unsafe, illegal, dangerous or inappropriate for their age.',
    'If a challenge or activity involves leaving home, interacting with another person, visiting a location, handling an object, or performing any physical activity, users and their parents/guardians are responsible for assessing whether it is safe and appropriate.',
  ]),
  const _Section('3. Personal Responsibility and Safety', paragraphs: [
    'Acha Karo encourages positive participation but does not control the circumstances in which users carry out activities.',
    'Users participate in challenges, deeds and activities voluntarily and at their own discretion and risk.',
    'Users must not undertake an activity merely to obtain points, badges, rewards or campaign progress if doing so could reasonably place themselves or another person in danger.',
    'Acha Karo is not responsible for injuries, losses, damage or other consequences arising from a user\'s participation in an activity that is outside Acha Karo\'s direct control, including activities performed independently by the user or activities undertaken contrary to safety instructions.',
    'Safety takes priority over completing a campaign.',
  ]),
  const _Section('4. Deeds, Challenges and Campaigns', paragraphs: [
    'Users must honestly report deeds and complete campaign activities as described.',
    'Users must not:',
  ], bullets: [
    'falsely claim to have completed an activity',
    'submit fraudulent or misleading information',
    'create multiple accounts to gain additional points or rewards',
    'manipulate leaderboards or campaign progress',
    'exploit technical errors or bugs',
    'impersonate another person',
    'interfere with another user\'s account or participation',
  ]),
  const _Section('', paragraphs: [
    'Acha Karo may remove fraudulent entries, points, badges, campaign progress or rewards and may restrict or suspend accounts involved in abuse or manipulation.',
  ]),
  const _Section('5. Points, Badges and Digital Rewards', paragraphs: [
    'Points, badges, skins, medals, digital collectibles and other campaign items are provided for participation and recognition.',
    'Unless specifically stated otherwise:',
  ], bullets: [
    'points have no cash value',
    'points cannot be exchanged for money',
    'points cannot be transferred between users',
    'digital items do not represent ownership of any company, asset or security',
    'Acha Karo may modify campaign rules, point values or availability where reasonably necessary',
  ]),
  const _Section('', paragraphs: [
    'Campaign-specific rewards are subject to the rules displayed for that campaign.',
  ]),
  const _Section('6. Campaign Changes', paragraphs: [
    'Campaigns may be temporary and may be changed, paused, extended or discontinued because of technical problems, safety concerns, availability, operational requirements or other circumstances.',
    'Acha Karo will make reasonable efforts to communicate material changes through the application or other official channels.',
  ]),
  const _Section('7. User Content and Submissions', paragraphs: [
    'Users may be invited to submit ideas, suggestions, photographs, artwork, writing, videos or other material.',
    'Users must only submit material that they have the right to submit.',
    'By voluntarily submitting material for an Acha Karo campaign or co-creation activity, the user grants Acha Karo permission to use, reproduce, adapt, display and publish that material for Acha Karo\'s platform, campaigns, promotional activities and related communications, without requiring additional payment unless a separate written agreement states otherwise.',
    'Acha Karo does not claim ownership of a user\'s original work merely because it has been submitted.',
  ]),
  const _Section('8. Co-Creation and Certificates', paragraphs: [
    'Certain campaigns may provide opportunities to participate in content development or other co-creation activities.',
    'Where Acha Karo issues a certificate or experience letter, it will describe the participation or contribution actually made by the user.',
    'Receiving a certificate or experience letter does not constitute employment by Acha Karo unless a separate employment agreement exists.',
  ]),
  const _Section('9. Third-Party Content', paragraphs: [
    'Acha Karo may link to or display content hosted by third parties, including YouTube and other websites or services.',
    'Acha Karo does not control third-party platforms and is not responsible for their availability, policies, content or terms.',
    'Users should review the applicable third-party terms when using those services.',
  ]),
  const _Section('10. Intellectual Property', paragraphs: [
    'The Acha Karo name, logo, application design, original artwork, campaign materials, software and other Acha Karo-created content belong to Acha Karo or its respective licensors unless otherwise stated.',
    'Users may not copy, modify, distribute, sell or commercially exploit Acha Karo\'s proprietary material without permission.',
  ]),
  const _Section('11. Account Suspension', paragraphs: [
    'Acha Karo may suspend or terminate an account where it reasonably believes that the user:',
  ], bullets: [
    'has violated these Terms',
    'has engaged in fraud or manipulation',
    'has submitted unlawful or harmful material',
    'has abused other users',
    'has attempted to compromise or misuse the platform',
  ]),
  const _Section('12. Availability', paragraphs: [
    'Acha Karo is provided on an evolving basis. As a startup and pilot platform, features may be added, removed, changed or temporarily unavailable.',
    'We do not guarantee that the application or every feature will always be available, uninterrupted or error-free.',
  ]),
  const _Section('13. Privacy', paragraphs: [
    'Your use of Acha Karo is also subject to our Privacy Policy, which explains what personal information we collect, why we collect it and how it may be used.',
    'The Privacy Policy forms part of these Terms.',
  ]),
  const _Section('14. Limitation of Responsibility', paragraphs: [
    'Acha Karo will take reasonable steps to operate the platform responsibly. However, Acha Karo cannot control every activity performed by users outside the application.',
    'Nothing in these Terms is intended to exclude or limit any liability that cannot lawfully be excluded or limited under applicable law.',
  ]),
  const _Section('15. Changes to These Terms', paragraphs: [
    'We may update these Terms as Acha Karo develops.',
    'When material changes are made, we may notify users through the application or another appropriate method.',
    'Continued use of Acha Karo after an updated version becomes effective constitutes acceptance of the updated Terms, to the extent permitted by applicable law.',
  ]),
  const _Section('16. Governing Law', paragraphs: [
    'These Terms are intended to be governed by the laws of the Islamic Republic of Pakistan, subject to any mandatory legal rights available to the user.',
  ]),
  const _Section('17. Contact', paragraphs: [
    'For questions, complaints or concerns regarding these Terms, reach out to us by submitting a feedback.',
  ]),
  const _Section('User Agreement', paragraphs: [
    'By selecting "I Agree" and creating an Acha Karo account, you confirm that:',
  ], bullets: [
    'you have read and understood these Terms & Conditions',
    'the information you provide is accurate',
    'you will participate honestly and responsibly',
    'if you are under 18, you have the knowledge and appropriate supervision of a parent or legal guardian',
    'you understand that safety takes priority over completing any Acha Karo campaign or challenge',
  ]),
];

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
              Expanded(child: Text('Terms & Conditions', style: AppFonts.fraunces(size: 17, weight: FontWeight.w600))),
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
                  Text('Effective Date: $_effectiveDate', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome to Acha Karo. By creating an account or using the Acha Karo application, you agree to these Terms & Conditions. If you do not agree, please do not use the application.',
                    style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  for (final s in _sections) ...[
                    if (s.heading.isNotEmpty) ...[
                      Text(s.heading, style: AppFonts.fraunces(size: 14, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                    ],
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
                  Text('Last Updated: $_effectiveDate', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
