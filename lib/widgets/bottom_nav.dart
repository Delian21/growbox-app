import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'micro_interactions.dart';

// ---------------------------------------------------------------------------
// Data Model
// ---------------------------------------------------------------------------

/// A single item in the bottom navigation bar.
class BottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isHighlighted;
  final int badgeCount;

  const BottomNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.isHighlighted = false,
    this.badgeCount = 0,
  });
}

// ---------------------------------------------------------------------------
// Floating Glassmorphism Bottom Nav
// ---------------------------------------------------------------------------

/// A floating, glassmorphism-styled bottom navigation bar.
///
/// Features:
///   - Floating pill shape with rounded corners (not flush to screen edge)
///   - Frosted-glass translucency via BackdropFilter + gradient overlay
///   - Spring-bounce indicator that overshoots and settles behind the active tab
///   - Active icon gets a soft gradient pill background + glow
///   - Labels always visible; active label is bold & green
///   - Optional badge counter (e.g. cart item count)
///   - Full dark-mode support via the C.* theme tokens
class BottomNav extends StatefulWidget {
  final List<BottomNavItem> items;
  final int activeIndex;
  final int? cartBadgeCount;

  const BottomNav({
    super.key,
    required this.items,
    this.activeIndex = -1,
    this.cartBadgeCount,
  });

  /// Convenience constructor for the standard 4-tab GROWBOX nav.
  ///
  /// [activeIndex] highlights that tab (0=home, 1=search, 2=cart, 3=profile).
  /// Provide navigation callbacks for each tab.
  static Widget growbox({
    Key? key,
    required int activeIndex,
    required VoidCallback onHome,
    required VoidCallback onSearch,
    required VoidCallback onCart,
    required VoidCallback onProfile,
    int? cartBadgeCount,
  }) {
    return BottomNav(
      key: key,
      activeIndex: activeIndex,
      cartBadgeCount: cartBadgeCount,
      items: [
        BottomNavItem(
          icon: Icons.home_outlined,
          label: 'Home',
          onTap: onHome,
          isActive: activeIndex == 0,
        ),
        BottomNavItem(
          icon: Icons.search,
          label: 'Search',
          onTap: onSearch,
          isActive: activeIndex == 1,
        ),
        BottomNavItem(
          icon: Icons.shopping_cart_outlined,
          label: 'Cart',
          onTap: onCart,
          isActive: activeIndex == 2,
          badgeCount: cartBadgeCount ?? 0,
        ),
        BottomNavItem(
          icon: Icons.person_outline,
          label: 'Profile',
          onTap: onProfile,
          isActive: activeIndex == 3,
        ),
      ],
    );
  }

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorController;
  late Animation<double> _indicatorAnim;
  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Start at position 0; didChangeDependencies will set the real position
    _indicatorAnim = const AlwaysStoppedAnimation(0);
  }

  bool _didInitPosition = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitPosition) {
      _didInitPosition = true;
      final start = _targetLeft(widget.activeIndex.clamp(0, widget.items.length - 1));
      _indicatorAnim = AlwaysStoppedAnimation(start);
      // Trigger a rebuild so the indicator renders at the correct position
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != oldWidget.activeIndex) {
      _animateIndicator(oldWidget.activeIndex, widget.activeIndex);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  double _targetLeft(int index) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final barWidth = (screenWidth * 0.88).clamp(280.0, 420.0);
    final itemWidth = barWidth / widget.items.length;
    return itemWidth * index + (itemWidth - 52) / 2;
  }

  void _animateIndicator(int from, int to) {
    final screenSize = MediaQuery.sizeOf(context);
    final barWidth = (screenSize.width * 0.88).clamp(280.0, 420.0);
    final itemWidth = barWidth / widget.items.length;
    final fromLeft = itemWidth * from.clamp(0, widget.items.length - 1) +
        (itemWidth - 52) / 2;
    final toLeft = itemWidth * to.clamp(0, widget.items.length - 1) +
        (itemWidth - 52) / 2;

    _indicatorAnim = Tween<double>(
      begin: fromLeft,
      end: toLeft,
    ).animate(
      CurvedAnimation(
        parent: _indicatorController,
        curve: Curves.easeOutBack,
      ),
    );

    _indicatorController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = C.isDark(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Sizing – percentage-based so the pill scales with screen width
    final barWidth = (screenWidth * 0.88).clamp(280.0, 420.0);
    const barHeight = 72.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: barHeight + 20, // extra room for the float + shadow
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(barHeight / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: barWidth,
                height: barHeight,
                clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barHeight / 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xCC1E1E1E),
                          const Color(0xAA252525),
                        ]
                      : [
                          const Color(0xF0FFFFFF),
                          const Color(0xE6F5F5F0),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? const Color(0x33FFFFFF)
                      : const Color(0x22000000),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x14000000),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: isDark
                        ? const Color(0x1A3EC930)
                        : const Color(0x1A1C4815),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Sliding indicator pill with spring bounce
                  AnimatedBuilder(
                    animation: _indicatorAnim,
                    builder: (context, _) {
                      final maxLeft = barWidth - 52.0;
                      return Positioned(
                        left: _indicatorAnim.value.clamp(0.0, maxLeft),
                        top: (barHeight - 52) / 2,
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      const Color(0xFF1A3D15),
                                      const Color(0xFF2D6B22),
                                    ]
                                  : [
                                      AppColors.primaryLight,
                                      const Color(0xFFB4F5A5),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? const Color(0x403EC930)
                                    : const Color(0x331C4815),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Nav items row – Expanded guarantees equal split, no overflow
                  Row(
                    children: List.generate(widget.items.length, (index) {
                      return Expanded(
                        child: _NavItem(
                          item: widget.items[index],
                          isActive: index == widget.activeIndex,
                          isDark: isDark,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

// ---------------------------------------------------------------------------
// Individual Nav Item
// ---------------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  final BottomNavItem item;
  final bool isActive;
  final bool isDark;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // On the dark-green pill the active icon/label must be white for
    // contrast; in light mode the brand green reads on the pale tile.
    final activeColor = isDark ? Colors.white : AppColors.primary;
    const inactiveColor = Color(0xFF666666);
    final darkInactive = const Color(0xFF999999);
    final iconColor = isActive
        ? activeColor
        : (isDark ? darkInactive : inactiveColor);

    return TapFeedback(
      onTap: item.onTap != null
          ? () {
              HapticFeedback.lightImpact();
              item.onTap!();
            }
          : null,
      child: SizedBox(
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with badge – smooth scale transition on active
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        item.icon,
                        key: ValueKey('${item.label}_$isActive'),
                        size: 22,
                        color: iconColor,
                      ),
                    ),
                  // Badge
                  if (item.badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33DC2626),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isActive ? 11 : 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? darkInactive : inactiveColor),
                  height: 1.0,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
