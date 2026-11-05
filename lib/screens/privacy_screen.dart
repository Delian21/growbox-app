import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

class ManagePrivacyScreen extends StatefulWidget {
  const ManagePrivacyScreen({super.key});

  @override
  State<ManagePrivacyScreen> createState() => _ManagePrivacyScreenState();
}

class _ManagePrivacyScreenState extends State<ManagePrivacyScreen> {
  bool personalizedRecommendations = true;
  bool marketingCommunications = false;
  bool analyticsData = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Manage Privacy'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The header carries the page name; the body starts with
                    // the explanation.
                    SizedBox(height: AppSpacing.lg),
                    Text('Choose how Growbox can use your information and communicate with you.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: C.textPrimary(context))),
                    SizedBox(height: 30),
                    _PrivacyToggleItem(
                      title: 'Personalized recommendations',
                      subtitle: 'Allow Growbox to use your activity to personalize products and recommendations.',
                      value: personalizedRecommendations,
                      onChanged: (v) => setState(() => personalizedRecommendations = v)),
                    _PrivacyToggleItem(
                      title: 'Marketing communications',
                      subtitle: 'Receive updates, offers, promotions and other marketing messages from Growbox.',
                      value: marketingCommunications,
                      onChanged: (v) => setState(() => marketingCommunications = v)),
                    _PrivacyToggleItem(
                      title: 'Analytics & usage data',
                      subtitle: 'Allow anonymous usage data to help us improve the Growbox experience.',
                      value: analyticsData,
                      onChanged: (v) => setState(() => analyticsData = v)),
                    SizedBox(height: AppSpacing.xxl),
                    Text('Your privacy matters to us. These settings can be updated at any time.',
                      style: TextStyle(fontSize: 14, height: 1.5, color: C.textMuted(context))),
                    SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggleItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggleItem({
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.divider(context), width: 1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                SizedBox(height: AppSpacing.sm - 2),
                Text(subtitle, style: TextStyle(fontSize: 14, height: 1.4, color: C.textMuted(context))),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: C.onPrimary(context),
            activeTrackColor: C.primary(context),
          ),
        ],
      ),
    );
  }
}
