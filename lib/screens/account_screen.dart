import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../data/mock_data.dart';
import 'change_email_screen.dart';
import 'change_phone_screen.dart';
import 'deactivation_screen.dart';
import 'privacy_screen.dart';

class AccountScreen extends StatelessWidget {
    const AccountScreen({super.key});

  /// Destructive account actions live here, away from the everyday menu.
  /// The deletion flow itself is untouched: a typed confirmation gates the
  /// same [DeactivationScreen] the profile used to open directly.
  Future<void> _confirmDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeactivationScreen()),
    );
  }

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
                    // Destructive action, kept last and away from the profile.
                    _AccountActionItem(
                      icon: Icons.delete_outline, title: 'Delete Account',
                      color: C.errorBright(context),
                      onTap: () => _confirmDeletion(context)),
                    // Clears the floating nav bar.
                    SizedBox(
                      height: BottomNavMetrics.contentInset(context),
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
  final Color? color;
  final VoidCallback onTap;

    const _AccountActionItem({required this.icon, required this.title, this.color, required this.onTap});

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
            Icon(icon, size: iconSize, color: color ?? AppColors.info),
              SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w400,
                color: color ?? C.textPrimary(context)))),
              SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right,
              size: (screenWidth * 0.07).clamp(26.0, 30.0),
              color: color ?? AppColors.info),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DELETE ACCOUNT CONFIRMATION
// ═══════════════════════════════════════════════════════════════════════

/// Requires the word DELETE to be typed before the destructive button wakes
/// up, so a stray tap can never start the deletion flow.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const String _keyword = 'DELETE';

  final TextEditingController _controller = TextEditingController();

  bool get _canDelete => _controller.text.trim() == _keyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Delete account',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: C.textPrimary(context),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This removes your profile, saved addresses and order history. '
              'Type $_keyword to confirm.',
              style: AppTypography.bodySmall.copyWith(
                color: C.textSecondary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: C.textPrimary(context)),
              decoration: AppDecorations.inputDecoration(
                hintText: _keyword,
                context: context,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Delete',
            style: TextStyle(
              color: _canDelete ? C.errorBright(context) : C.textMuted(context),
            ),
          ),
        ),
      ],
    );
  }
}
