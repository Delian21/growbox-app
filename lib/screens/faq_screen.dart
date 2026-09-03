import 'package:flutter/material.dart';
import '../theme.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  int? expandedIndex;

  final List<Map<String, String>> faqItems = [
    {
      'question': 'What is GROWBOX?',
      'answer':
          'GROWBOX is an agricultural marketplace that makes it easier to discover and buy agricultural products and other offerings from vendors.',
    },
    {
      'question': 'How do I place an order?',
      'answer':
          'Find the product you want, add it to your cart, review your order and proceed to checkout. Follow the instructions provided to complete your purchase.',
    },
    {
      'question': 'How do I find a product or vendor?',
      'answer':
          'You can browse available categories or use the Search feature to look for products and vendors.',
    },
    {
      'question': 'How do I pay for my order?',
      'answer':
          'At checkout, you will be shown the available payment options. Select your preferred option and follow the instructions to complete your payment.',
    },
    {
      'question': 'How long does delivery take?',
      'answer':
          'Delivery time can vary depending on the vendor, product and delivery location. Your order information will provide the applicable delivery details.',
    },
    {
      'question': 'Can I cancel my order?',
      'answer':
          'Order cancellation depends on the status of your order. If cancellation is available, you will be able to follow the applicable cancellation process.',
    },
    {
      'question': 'How can I contact a vendor?',
      'answer':
          'Vendor contact options will be available where applicable. You can also contact GROWBOX support (uianetwork.ng@gmail.com) if you need assistance with an order.',
    },
    {
      'question': 'What happens if my order is delayed?',
      'answer':
          'If your order is delayed, check your order information for the latest status. If you need further assistance, contact GROWBOX support (uianetwork.ng@gmail.com).',
    },
    {
      'question': 'How do I change my account information?',
      'answer':
          'Go to your Profile and open Account. From there, you can update the account information and settings currently available to you.',
    },
    {
      'question': 'How do I report a problem with my order?',
      'answer':
          'If you experience a problem with an order, contact GROWBOX support (uianetwork.ng@gmail.com) and provide your order details so the issue can be reviewed.',
    },
  ];

  void toggleFAQ(int index) {
    setState(() => expandedIndex = expandedIndex == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        size: 24, color: AppColors.black),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'FAQ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title ────────────────────────────────────
                    Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Find answers to some of the most common questions about using GROWBOX.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // ── FAQ Items ────────────────────────────────
                    ...List.generate(faqItems.length, (index) {
                      final faq = faqItems[index];
                      final isExpanded = expandedIndex == index;
                      return _buildFAQItem(faq, isExpanded, index);
                    }),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Contact Card ─────────────────────────────
                    _buildContactCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(
      Map<String, String> faq, bool isExpanded, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => toggleFAQ(index),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq['question']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AppColors.primaryLight
                            : C.surfaceLight(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: isExpanded
                            ? AppColors.primaryDark
                            : AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  faq['answer']!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.grey600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline,
                  size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              const Text(
                'Still need help?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'If you cannot find the answer you are looking for, contact GROWBOX support (uianetwork.ng@gmail.com) for assistance.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}
