import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/animated_entrance.dart';

class NotificationsScreen extends StatefulWidget {
    const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool pushNotifications = false;

  // Mock notifications
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Order Delivered',
      'message': 'Your order #GBX-10431 has been delivered successfully.',
      'time': '2 hours ago',
      'icon': Icons.check_circle_outline,
      'color': AppColors.success,
    },
    {
      'title': 'New Vendor',
      'message': 'Check out Cereals Greetings for fresh cereals!',
      'time': '1 day ago',
      'icon': Icons.storefront_outlined,
      'color': AppColors.primaryDark,
    },
    {
      'title': 'Promotion',
      'message': 'Get 10% off on your next order from Green Farm.',
      'time': '3 days ago',
      'icon': Icons.local_offer_outlined,
      'color': AppColors.gold,
    },
    {
      'title': 'Order Update',
      'message': 'Your order #GBX-10482 is being prepared.',
      'time': '5 days ago',
      'icon': Icons.receipt_long_outlined,
      'color': AppColors.primaryDark,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        size: 24, color: C.textPrimary(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            // ── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsCard(),
                    SizedBox(height: AppSpacing.xxl),
                    _buildSectionTitle('Recent'),
                    SizedBox(height: AppSpacing.md),
                    ..._notifications.asMap().entries.map((entry) {
                      return AnimatedEntrance(index: entry.key, child: _buildNotificationCard(entry.value));
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style:   TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: C.textPrimary(context),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      width: double.infinity,
      padding:   EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset:   Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:   Icon(Icons.notifications_none_outlined,
                    size: 20, color: AppColors.primaryDark),
              ),
                SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: C.textPrimary(context),
                      ),
                    ),
                      SizedBox(height: 2),
                      Text(
                      'Get notified about order updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: pushNotifications,
                onChanged: (value) =>
                    setState(() => pushNotifications = value),
                activeThumbColor: AppColors.primaryDark,
                activeTrackColor: AppColors.primaryLight,
                inactiveThumbColor: AppColors.grey500,
                inactiveTrackColor: AppColors.grey300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] as String;
    final message = notification['message'] as String;
    final time = notification['time'] as String;
    final icon = notification['icon'] as IconData;
    final color = notification['color'] as Color;

    return Container(
      margin:   EdgeInsets.only(bottom: AppSpacing.sm),
      padding:   EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset:   Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
            SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
                  SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:   TextStyle(
                    fontSize: 13,
                    color: C.textMuted(context),
                  ),
                ),
                  SizedBox(height: 6),
                Text(
                  time,
                  style:   TextStyle(
                    fontSize: 11,
                    color: C.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
