import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../data/mock_data.dart';
import 'change_email_screen.dart';
import 'change_phone_screen.dart';
import 'privacy_screen.dart';

class AccountScreen extends StatelessWidget {
    const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final horizontalPadding = (screenWidth * 0.055).clamp(16.0, 24.0);
    final topPadding = (screenHeight * 0.055).clamp(24.0, 50.0);
    final headerFontSize = (screenWidth * 0.043).clamp(15.0, 18.0);

    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, AppSpacing.xxl),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(width: 40, height: 40,
                      child: Center(child: Icon(Icons.arrow_back,
                        size: (screenWidth * 0.06).clamp(22.0, 26.0),
                        color: AppColors.info))),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Account',
                    style: TextStyle(fontSize: headerFontSize,
                      fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _AccountMenuItem(icon: Icons.person_outline,
                      title: CustomerData.name ?? 'Customer'),
                    _AccountMenuItem(icon: Icons.mail_outline,
                      title: CustomerData.email ?? 'No email added'),
                    SizedBox(height: AppSpacing.md),
                    _AccountActionItem(
                      icon: Icons.lock_outline, title: 'Change email',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChangeEmailScreen()))),
                    _AccountActionItem(
                      icon: Icons.phone_iphone_outlined, title: 'Change phone number',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChangePhoneNumberScreen()))),
                    _AccountActionItem(
                      icon: Icons.privacy_tip_outlined, title: 'Manage Privacy',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManagePrivacyScreen()))),
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
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

class _AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

    const _AccountMenuItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = (screenWidth * 0.06).clamp(22.0, 26.0);
    final textSize = (screenWidth * 0.04).clamp(14.0, 16.0);

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: AppColors.info),
            SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w400, color: C.textPrimary(context)))),
        ],
      ),
    );
  }
}

class _AccountActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

    const _AccountActionItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = (screenWidth * 0.06).clamp(22.0, 26.0);
    final textSize = (screenWidth * 0.04).clamp(14.0, 16.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints:   BoxConstraints(minHeight: 57),
        padding:   EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration:   BoxDecoration(
          border: Border(top: BorderSide(color: C.divider(context), width: 1))),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: AppColors.info),
              SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w400, color: C.textPrimary(context)))),
              SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right,
              size: (screenWidth * 0.07).clamp(26.0, 30.0),
              color: AppColors.info),
          ],
        ),
      ),
    );
  }
}
