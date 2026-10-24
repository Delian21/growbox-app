import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../data/mock_data.dart';
import 'account_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'faq_screen.dart';
import 'notifications_screen.dart';
import 'address_management_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// One vertical gap above every section label, including the first one under
  /// the profile card.
  static const double _sectionGap = AppSpacing.xxl;

  /// The profile lives in globals, not a notifier, so repaint after editing.
  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rawName = CustomerData.name?.trim() ?? '';
    final rawEmail = CustomerData.email?.trim() ?? '';
    // "Customer" is the placeholder the app falls back to, so a real name is
    // anything else.
    final nameIsDefault = rawName.isEmpty;
    final emailIsMissing = rawEmail.isEmpty;

    final profileName = nameIsDefault ? 'Customer' : rawName;
    final profileInitial = profileName[0].toUpperCase();
    final email = emailIsMissing ? 'No email added' : rawEmail;

    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              // ── Header with Help button ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FAQScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: C.surfaceLight(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.help_outline,
                                size: 18,
                                color: C.textPrimary(context)),
                            const SizedBox(width: 6),
                            Text(
                              'Help',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: C.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // ── Profile Card ─────────────────────────────
              _buildProfileCard(
                context,
                initial: profileInitial,
                name: profileName,
                email: email,
                showDetailsPrompt: nameIsDefault || emailIsMissing,
                onEdit: _openEditProfile,
              ),
              // ── Menu Sections ────────────────────────────
              _buildMenuSection(context, 'Orders', [
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Order History',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderHistoryScreen()),
                  ),
                ),
                _MenuItem(
                  icon: Icons.favorite_border,
                  title: 'Favorites',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FavoritesScreen()),
                  ),
                ),
              ]),
              _buildMenuSection(context, 'Account', [
                _MenuItem(
                  icon: Icons.person_outline,
                  title: 'Account Settings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AccountScreen()),
                  ),
                ),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'My Addresses',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AddressManagementScreen()),
                  ),
                ),
                _MenuItem(
                  icon: Icons.notifications_none_outlined,
                  title: 'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NotificationsScreen()),
                  ),
                ),
              ]),
              _buildMenuSection(context, 'Preferences', [
                const _ThemeModeSelector(),
              ]),
              const SizedBox(height: AppSpacing.xxl),
              // ── Logout ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GestureDetector(
                  onTap: () => _confirmLogout(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: C.errorBright(context).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_outlined,
                            size: 18, color: C.errorBright(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: C.errorBright(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // ── Version ──────────────────────────────────
              Center(
                child: Text(
                  'Version 2026.20.vfhvf',
                  style: TextStyle(
                    fontSize: 12,
                    color: C.textMuted(context),
                  ),
                ),
              ),
              // Clears the floating nav bar.
              SizedBox(
                height: BottomNavMetrics.contentInset(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Log Out',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary(dialogContext))),
          content: Text('Are you sure you want to log out?',
              style: TextStyle(color: C.textPrimary(dialogContext))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                CustomerData.clear();
                Navigator.pop(dialogContext);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have been logged out.'),
                  ),
                );
              },
              child: Text(
                'Log Out',
                style: TextStyle(color: C.errorBright(dialogContext)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required String initial,
    required String name,
    required String email,
    required bool showDetailsPrompt,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        key: const ValueKey('profileCard'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Name and email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: C.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: C.textMuted(context),
                    ),
                  ),
                  // Prompt shown only while the profile is incomplete.
                  if (showDetailsPrompt) ...[
                    const SizedBox(height: AppSpacing.sm),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: C.accentOrange(context),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'Add your name and email',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: C.accentOrange(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit icon
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context, String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            // Same gap above every label, whichever block precedes it.
            const SizedBox(height: _sectionGap),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.textMuted(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Container(
            key: ValueKey('sectionCard-$title'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: C.surface(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;
                return Column(
                  children: [
                    item,
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 52,
                        color: C.divider(context),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MENU ITEM
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: C.textMuted(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: C.textPrimary(context),
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: C.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// APPEARANCE SELECTOR
//
// Replaces the old dark-mode Switch, which read `value == ThemeMode.dark`:
// with the app following the system by default that is false even while the
// UI renders dark, so the switch showed "off" on a dark app. The selected
// option here is simply the stored ThemeMode, so System/Light/Dark always
// match reality.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  static const List<(ThemeMode, String, IconData)> _options = [
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    // Reading through ThemeProvider rebuilds this widget when the mode changes.
    final notifier = ThemeProvider.of(context);
    final current = _options.firstWhere((option) => option.$1 == notifier.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        AppSpacing.md,
        14,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(current.$3, size: 20, color: C.textMuted(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: C.surfaceLight(context),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                for (final option in _options)
                  Expanded(
                    child: _buildOption(
                      context,
                      notifier,
                      mode: option.$1,
                      label: option.$2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    ThemeNotifier notifier, {
    required ThemeMode mode,
    required String label,
  }) {
    final selected = notifier.value == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => notifier.select(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
        decoration: BoxDecoration(
          color: selected ? C.primary(context) : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? C.onPrimary(context) : C.textMuted(context),
          ),
        ),
      ),
    );
  }
}
