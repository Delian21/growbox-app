import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../data/mock_data.dart';
import 'account_screen.dart';
import 'favorites_screen.dart';
import 'faq_screen.dart';
import 'notifications_screen.dart';
import 'deactivation_screen.dart';
import 'address_management_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileName = CustomerData.name != null &&
            CustomerData.name!.trim().isNotEmpty
        ? CustomerData.name!.trim()
        : 'Customer';
    final profileInitial =
        profileName.isNotEmpty ? profileName[0].toUpperCase() : 'C';
    final email = CustomerData.email ?? 'No email added';

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
              _buildProfileCard(context, profileInitial, profileName, email),
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
                _DarkModeToggle(),
              ]),
              _buildMenuSection(context, '', [
                _MenuItem(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  color: AppColors.error,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DeactivationScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              // ── Logout ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GestureDetector(
                  onTap: () {
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
                              onPressed: () =>
                                  Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                CustomerData.clear();
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'You have been logged out.'),
                                  ),
                                );
                              },
                              child: const Text('Log Out',
                                  style: TextStyle(
                                      color: AppColors.error)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_outlined,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
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
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context, String initial, String name, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: C.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            // Edit icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.primaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context, String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
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
            width: double.infinity,
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
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? C.textPrimary(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? C.textMuted(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: itemColor,
                ),
              ),
            ),
            if (color == null)
              Icon(Icons.chevron_right, size: 20, color: C.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DARK MODE TOGGLE
class _DarkModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeProvider.of(context);
    final isDark = themeNotifier.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            size: 20,
            color: C.textMuted(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: C.textPrimary(context),
              ),
            ),
          ),
          Switch(
            value: isDark,
            onChanged: (_) => themeNotifier.toggle(),
            activeThumbColor: AppColors.primaryDark,
            activeTrackColor: AppColors.primaryLight,
            inactiveThumbColor: C.textMuted(context),
            inactiveTrackColor: C.surfaceLighter(context),
          ),
        ],
      ),
    );
  }
}
