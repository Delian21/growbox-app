import 'package:flutter/material.dart';

import '../widgets/policy_page.dart';
import 'terms_screen.dart';

/// GROWBOX Privacy Policy, reached from checkout.
///
/// This is the policy itself; the toggles that control personalised
/// recommendations, marketing and analytics live in Profile › Manage Privacy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const List<PolicySection> _sections = [
    PolicySection('What we collect', [
      'Account details you give us: your name, email address and phone number.',
      'Delivery details: the addresses you save, including the street, area, '
          'landmark and contact number for each, and the address recorded on '
          'each order.',
      'Order details: what you bought, from which vendor, the amounts, the '
          'delivery status and your order history.',
      'Browsing area: the area you pick on the map, used to show vendors near '
          'you. It is separate from your delivery addresses.',
      'Support messages you send us, and basic technical information such as '
          'the device and app version you are using, so we can fix problems.',
      'We do not store full card numbers. Card and transfer details are '
          'handled by the payment provider that processes them.',
    ]),
    PolicySection('How we use it', [
      'To take, pack and deliver your orders, and to tell you and the rider '
          'where the order is going.',
      'To show produce from vendors that deliver to your area, and to remember '
          'your addresses, cart and order history between visits.',
      'To answer your questions, resolve problems with an order and handle '
          'refunds.',
      'To keep the marketplace safe — for example, detecting fraudulent or '
          'abusive orders — and to meet our legal and accounting obligations.',
      'To improve the app, using aggregated information about how features are '
          'used. You can turn analytics off in Manage Privacy.',
    ]),
    PolicySection('Who we share it with', [
      'Vendors: the items, quantities and the name on an order so they can pack '
          'it.',
      'Riders and delivery partners: your name, phone number and the delivery '
          'address for the order they are carrying.',
      'Payment providers, so a payment can be taken or refunded.',
      'Service providers who host and support the app, under contracts that '
          'limit them to using your data for that purpose.',
      'Authorities, where the law requires it. We do not sell your personal '
          'information.',
    ]),
    PolicySection('Where your data lives', [
      'Your saved addresses, cart and order history are kept on your device so '
          'the app works between sessions, and are associated with the account '
          'that is signed in. Signing out does not delete them; deleting an '
          'address removes it from your saved list.',
      'When you are signed in, order and account information is also held on '
          'our servers so it can be seen across your devices and by the vendor '
          'and rider fulfilling an order.',
    ]),
    PolicySection('Your choices', [
      'You can edit or delete any saved delivery address, and choose which one '
          'orders are delivered to, in Profile › My Addresses.',
      'You can control personalised recommendations, marketing messages and '
          'analytics in Profile › Manage Privacy.',
      'You can ask us for a copy of the personal information we hold about you, '
          'ask us to correct it, or ask us to delete your account and its data. '
          'Deleting your account removes your profile, saved addresses and '
          'order history from the app.',
    ]),
    PolicySection('Keeping your data', [
      'We keep order records while your account is open and for as long as '
          'accounting and consumer-protection rules require afterwards. When '
          'that period ends the records are deleted or anonymised. Data you '
          'keep only on your device is removed when you delete it or uninstall '
          'the app.',
    ]),
    PolicySection('Children', [
      'GROWBOX is intended for adults. The app is not directed at children '
          'under 18, and we do not knowingly collect their personal '
          'information. If you believe a child has given us data, contact us '
          'and we will remove it.',
    ]),
    PolicySection('Security', [
      'We protect your information with encryption in transit and by limiting '
          'access to the people and systems that need it to run the service. No '
          'system is perfectly secure; if you think your account has been '
          'compromised, contact us immediately so we can help.',
    ]),
    PolicySection('Changes to this policy', [
      'If this policy changes, we will update the date at the top of the page. '
          'Where a change materially affects how we use your information, we '
          'will tell you in the app before it takes effect.',
    ]),
    PolicySection('Contact us', [
      'Questions about this policy or your data? Email '
          '${TermsScreen.supportEmail} and we will respond as soon as we can.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return const PolicyPage(
      title: 'Privacy Policy',
      lastUpdated: 'Last updated 25 October 2026',
      intro: 'This policy explains what GROWBOX collects when you use the app, '
          'why we collect it, who we share it with and the choices you have.',
      sections: _sections,
    );
  }
}
