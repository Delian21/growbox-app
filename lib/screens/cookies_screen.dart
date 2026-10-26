import 'package:flutter/material.dart';

import '../widgets/policy_page.dart';
import 'terms_screen.dart';

/// GROWBOX Cookies Policy, reached from sign-up and checkout.
///
/// Short on purpose: the app sets no advertising or tracking cookies, so the
/// page only has to describe the local storage it genuinely uses.
class CookiesScreen extends StatelessWidget {
  const CookiesScreen({super.key});

  static const List<PolicySection> _sections = [
    PolicySection('What cookies are', [
      'Cookies are small pieces of data a website or app stores on your '
          'device. Apps use the same idea under other names — local storage, '
          'preferences or an app cache — and this policy covers all of them.',
    ]),
    PolicySection('What GROWBOX stores', [
      'We keep the things that make the app work the way you left it: your '
          'sign-in state, your theme choice, the delivery addresses you save, '
          'the options in Profile › Manage Privacy, and prompts you have '
          'dismissed. These are stored on your device and are not shared with '
          'vendors or advertisers.',
      'When you use GROWBOX in a browser, the same information is kept in that '
          "browser's local storage for the site. Clearing it signs you out and "
          'removes the addresses saved on that device.',
    ]),
    PolicySection('What we do not use', [
      'No advertising cookies. No cross-site tracking. No third-party '
          'analytics that follows you around the web. We do not sell data '
          'about you.',
    ]),
    PolicySection('Other services', [
      'If you pay through a payment provider, that provider may set its own '
          'cookies while you complete the payment on its page. Those are '
          'covered by its own policy, not this one.',
    ]),
    PolicySection('Managing cookies', [
      'You can clear the stored data at any time by signing out and clearing '
          'the app or site data from your device settings; you can also turn '
          'off personalised recommendations, marketing and analytics in '
          'Profile › Manage Privacy. Clearing the data does not delete orders '
          'already placed.',
    ]),
    PolicySection('Contact us', [
      'Questions about this policy: ${TermsScreen.supportEmail}. See also our '
          'Privacy Policy for what we collect and why.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return const PolicyPage(
      title: 'Cookies Policy',
      lastUpdated: 'Last updated 25 October 2026',
      intro:
          'This policy explains the small amount of data GROWBOX stores on '
          'your device, why we store it, and how to clear it.',
      sections: _sections,
    );
  }
}
