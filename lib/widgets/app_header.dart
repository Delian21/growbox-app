import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's one page header for pushed screens.
///
/// A 48×48 back target on the left, a centred 20px/semibold title and optional
/// trailing icons, all in [C.textPrimary] so nothing is drawn in a dim grey that
/// disappears in dark mode. The header paints the page background, so content
/// scrolling underneath never collides with the title, and it can show a 1px
/// divider once the page has scrolled.
///
/// It expects to live inside a `SafeArea`; screens put it at the top of their
/// own `Column`, which keeps the scrollable below it free to fill the rest.
class AppHeader extends StatefulWidget {
  final String title;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;

  /// Trailing 48×48 controls. Empty leaves a matching 48px gap so the title
  /// stays optically centred.
  final List<Widget> actions;

  /// When set, the hairline divider fades in as soon as the page scrolls.
  final ScrollController? scrollController;

  /// Force the divider on (a screen whose content sits flush under the header).
  final bool showDivider;

  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.scrollController,
    this.showDivider = false,
  });

  /// Height of the bar itself, excluding the divider.
  static const double height = 56;

  /// Width of the back target and of the gap that balances it.
  static const double actionWidth = 48;

  /// The hairline under the bar, for measuring it in tests.
  static const Key dividerKey = ValueKey('appHeaderDivider');

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _scrolled = false;

  /// The Scaffold's scroll observer, which reports the page's own scrollables
  /// without every screen having to own a controller.
  ScrollNotificationObserverState? _observer;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (observer != _observer) {
      _observer?.removeListener(_onScrollNotification);
      _observer = observer;
      _observer?.addListener(_onScrollNotification);
    }
  }

  @override
  void didUpdateWidget(covariant AppHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScrollNotification);
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScrollNotification(ScrollNotification notification) {
    // Only the page itself: a horizontal carousel or a nested list inside the
    // page must not pin the hairline on.
    if (notification.depth != 0) return;
    _setScrolled(notification.metrics.pixels > 0);
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    _setScrolled(controller.offset > 0);
  }

  void _setScrolled(bool scrolled) {
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  bool get _dividerVisible => widget.showDivider || _scrolled;

  @override
  Widget build(BuildContext context) {
    final dividerColour = C.divider(context);

    return Container(
      color: C.background(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: AppHeader.height,
            child: Stack(
              children: [
                // Back target: 48×48 however large the glyph is drawn.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onBack ?? () => Navigator.maybePop(context),
                      child: SizedBox(
                        width: AppHeader.actionWidth,
                        height: AppHeader.actionWidth,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            size: 24,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // True centring: the title is independent of the action count.
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppHeader.actionWidth,
                      ),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.title.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.actions.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions,
                    ),
                  ),
              ],
            ),
          ),
          // Hairline that only appears once content has moved under the header.
          AnimatedContainer(
            key: AppHeader.dividerKey,
            duration: const Duration(milliseconds: 150),
            height: 1,
            color: _dividerVisible ? dividerColour : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
