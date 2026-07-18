import 'package:flutter/material.dart';

import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTANT — STARTING DRAFT ONLY.
//
// The Privacy Policy and Terms of Service below are a reasonable first draft
// covering the data this app actually handles. Before store submission the app
// owner MUST:
//   1. Have this reviewed by a qualified legal professional for the operating
//      jurisdiction(s) (this app targets Australian rentals — see Privacy Act
//      1988 / Australian Privacy Principles).
//   2. Fill in the real business/legal entity name and a working contact email
//      (see the `_contactEmail` placeholder below).
//   3. Host the finalised policy at a PUBLIC URL and reference that URL in the
//      App Store / Google Play store listing metadata (see `privacyPolicyUrl`).
// ─────────────────────────────────────────────────────────────────────────────

/// Public URL where the hosted Privacy Policy lives. Store metadata (App Store
/// Connect / Google Play Console) requires a reachable privacy-policy URL — set
/// this to the real hosted address before submission.
// TODO: Host the privacy policy publicly and replace this placeholder.
const String privacyPolicyUrl = 'TODO_HOST_THIS';

/// Contact address surfaced in the policy text. Replace with a monitored inbox.
// TODO: Replace with the app owner's real contact email.
const String _contactEmail = 'TODO_HOST_THIS (e.g. privacy@yourdomain.example)';

/// Last time the drafted policy text was materially updated. Keep in sync when
/// the owner edits the finalised copy.
const String _lastUpdated = '18 July 2026';

/// Combined Privacy Policy + Terms of Service screen. Reachable from the signup
/// screen and the settings sheet via the top-level `/legal` route, so it works
/// both before sign-in and from inside the app shell.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Terms')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Title('Privacy Policy'),
                _Muted('Last updated: $_lastUpdated'),
                SizedBox(height: 16),

                _Body(
                  'This Privacy Policy explains what information Leasely ("we", '
                  '"us", the "app") collects, how we use it, and the choices you '
                  'have. By creating an account or using the app you agree to the '
                  'practices described here.',
                ),

                _Heading('Information we collect'),
                _Body(
                  'We collect information you provide and information generated as '
                  'you use the app:',
                ),
                _Bullet('Contact details — your name, email address, and (optionally) '
                    'phone number, used to create and identify your account.'),
                _Bullet('Emergency and lifestyle contacts — if you choose to add them. '
                    'These may include another person\'s name and phone number. Only '
                    'add someone else\'s details if you have their permission.'),
                _Bullet('User content — photos, audio voice recordings, chat messages, '
                    'and lease or verification documents you upload or send within the '
                    'app.'),
                _Bullet('Financial information — rent, bills, payment history, and '
                    'shared-expense records you enter to manage your household.'),
                _Bullet('Identifiers — a Firebase user ID (UID) assigned to your '
                    'account, plus basic technical data needed to operate the service.'),

                _Heading('How we use your information'),
                _Bullet('To create your account and authenticate you when you sign in.'),
                _Bullet('To provide core features — housemate management, bills and '
                    'rent tracking, messaging, cleaning rosters, listings, and '
                    'document sharing.'),
                _Bullet('To sync your household\'s shared data between members and '
                    'across your devices.'),
                _Bullet('To send you reminders and notifications you have enabled.'),
                _Bullet('To keep the service secure and to comply with legal '
                    'obligations.'),
                _Body('We do not sell your personal information.'),

                _Heading('Where your data is stored'),
                _Body(
                  'Your data is stored using Google Firebase (Firebase '
                  'Authentication, Cloud Firestore, and Firebase Storage), which '
                  'runs on Google Cloud infrastructure. Some data may be processed '
                  'on servers located outside your country. We rely on Google '
                  'Cloud\'s security controls to protect data in transit and at '
                  'rest.',
                ),

                _Heading('Retention'),
                _Body(
                  'We keep your information for as long as your account is active. '
                  'Household content you contribute (for example messages or shared '
                  'bills) may remain visible to other members of that household even '
                  'after you leave it. When you delete your account we remove your '
                  'profile record and Firebase login as described below.',
                ),

                _Heading('Your rights and choices'),
                _Bullet('Access and correction — you can view and update your profile '
                    'details in the app.'),
                _Bullet('Account deletion — you can permanently delete your account at '
                    'any time from Settings → Delete account. This removes your '
                    'Firebase login and your user profile record, and removes you from '
                    'your household\'s member list.'),
                _Bullet('Notifications — you can turn reminders on or off in Settings.'),

                _Heading('Children'),
                _Body(
                  'The app is intended for adults managing shared housing and is not '
                  'directed at children.',
                ),

                _Heading('Contact'),
                _Body(
                  'Questions about this policy or your data? Contact us at '
                  '$_contactEmail.',
                ),

                SizedBox(height: 28),
                Divider(),
                SizedBox(height: 20),

                _Title('Terms of Service'),
                _Muted('Last updated: $_lastUpdated'),
                SizedBox(height: 16),

                _Body(
                  'These Terms govern your use of the Leasely app. By using the app '
                  'you agree to them.',
                ),

                _Heading('Your account'),
                _Body(
                  'You are responsible for keeping your login credentials secure and '
                  'for the activity that happens under your account. Provide accurate '
                  'information and keep it up to date.',
                ),

                _Heading('Acceptable use'),
                _Bullet('Use the app only for lawful purposes related to managing '
                    'shared housing.'),
                _Bullet('Do not upload content you do not have the right to share, or '
                    'that is unlawful, harassing, or infringing.'),
                _Bullet('Do not attempt to disrupt, reverse engineer, or gain '
                    'unauthorised access to the service.'),

                _Heading('Your content'),
                _Body(
                  'You retain ownership of the content you submit. You grant us the '
                  'limited permission needed to store, display, and share that '
                  'content with the household members you choose, so the app can '
                  'function.',
                ),

                _Heading('Financial features'),
                _Body(
                  'Rent, bills, and expense tracking are provided for convenience to '
                  'help households organise shared costs. They are recordkeeping '
                  'tools only and do not constitute financial, legal, or tax advice.',
                ),

                _Heading('Service availability'),
                _Body(
                  'The app is provided on an "as is" and "as available" basis. We do '
                  'not guarantee uninterrupted or error-free operation and may '
                  'change or discontinue features.',
                ),

                _Heading('Termination'),
                _Body(
                  'You may stop using the app and delete your account at any time. We '
                  'may suspend or terminate access if these Terms are breached.',
                ),

                _Heading('Contact'),
                _Body('Questions about these Terms? Contact us at $_contactEmail.'),

                SizedBox(height: 24),
                _Muted(
                  'This document is a starting draft and must be reviewed by a '
                  'qualified legal professional and hosted at a public URL before '
                  'store submission.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.55, color: HomiesColors.text),
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 10),
              child: Icon(Icons.circle, size: 5, color: HomiesColors.textDim),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: HomiesColors.text),
              ),
            ),
          ],
        ),
      );
}

class _Muted extends StatelessWidget {
  final String text;
  const _Muted(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, height: 1.45, color: HomiesColors.textFaint),
      );
}
