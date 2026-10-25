import 'package:flutter/material.dart';

import '../widgets/policy_page.dart';

/// GROWBOX Terms & Conditions, reached from checkout.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String supportEmail = 'uianetwork.ng@gmail.com';

  static const List<PolicySection> _sections = [
    PolicySection('1. About these terms', [
      'These terms are the agreement between you and GROWBOX when you use the '
          'app, browse the marketplace or place an order. By creating an '
          'account or ordering, you accept them.',
      'GROWBOX is a marketplace. The produce you buy is grown, prepared and '
          'packed by independent farms and food vendors listed in the app; we '
          'run the storefront, take your order and arrange the delivery.',
    ]),
    PolicySection('2. Your account', [
      'Give us accurate details — your name, a phone number we can reach you '
          'on and a delivery address a rider can find. Orders sent to an '
          'incomplete address may be delayed or cancelled.',
      'You are responsible for activity on your account. Keep your sign-in '
          'details private and contact us straight away if you think someone '
          'else has used your account. We may suspend an account that is being '
          'misused or that we reasonably believe is fraudulent.',
    ]),
    PolicySection('3. Orders and prices', [
      'Prices are in naira and are the prices shown in the app at the moment '
          'you place your order. A delivery fee is charged once for each vendor '
          'in your box; the fee, the goods and the payable total are shown on '
          'the checkout screen before you order.',
      'Your order is accepted when it is confirmed in the app. If an item turns '
          'out to be unavailable, the vendor may contact you to agree a '
          'replacement or we may refund that item. If a price was clearly '
          'mistaken, we may cancel the affected order and refund what you paid '
          'rather than deliver at the wrong price.',
    ]),
    PolicySection('4. Delivery', [
      'Delivery times shown in the app are estimates, not guarantees. Weather, '
          'traffic and vendor preparation can move them. We will keep the '
          'status in the app up to date so you can follow the delivery.',
      'Please make sure someone can receive the order at the address you '
          'selected, and check it on arrival. The rider may call the phone '
          'number saved on that address.',
    ]),
    PolicySection('5. Cancellations, refunds and replacements', [
      'You can cancel an order until the vendor starts packing it. After that, '
          'contact support and we will do what we can — a box that is already '
          'with a rider usually cannot be recalled.',
      'If something arrives damaged, missing or not what you ordered, tell us '
          'within 24 hours of delivery with your order number and, where you '
          'can, a photo. We will arrange a replacement or a refund to the '
          'original payment method; refunds are typically completed within '
          '3–10 business days.',
    ]),
    PolicySection('6. Produce from independent vendors', [
      'Each vendor is responsible for the quality, freshness, labelling and '
          'safety of what they sell. We choose vendors carefully and will '
          'follow up on any problem you report, but the goods are supplied by '
          'the vendor.',
      'We will not substitute an item without asking you first.',
    ]),
    PolicySection('7. Acceptable use', [
      'Use the app lawfully and only for genuine orders. Do not place orders '
          'you do not intend to pay for, scrape or copy the catalogue, attempt '
          'to disrupt the service, or use another person\'s account without '
          'their permission.',
    ]),
    PolicySection('8. Our liability', [
      'Nothing in these terms limits liability that cannot be limited by law, '
          'including for death, personal injury or fraud.',
      'To the extent the law allows, we are not liable for indirect or '
          'consequential losses, such as lost profits or lost opportunities. '
          'Our responsibility for an order is limited to the amount you paid '
          'for that order.',
    ]),
    PolicySection('9. Changes to these terms', [
      'We may update these terms as the service changes. The date at the top '
          'of this page shows the current version. If a change materially '
          'affects your rights we will tell you in the app before it applies, '
          'and continuing to use GROWBOX after that means you accept the '
          'updated terms.',
    ]),
    PolicySection('10. Contact us', [
      'Questions about these terms, an order or a refund? Email '
          '$supportEmail with your order number and we will get back to you.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return const PolicyPage(
      title: 'Terms & Conditions',
      lastUpdated: 'Last updated 25 October 2026',
      intro: 'Please read these terms before you order. They explain how the '
          'GROWBOX marketplace works, what you can expect from an order, and '
          'what we ask of you.',
      sections: _sections,
    );
  }
}
