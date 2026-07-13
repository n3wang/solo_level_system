// lib/widgets/common/standard_tab_app_bar.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Shared top tab bar matching the Stats (Overview) pattern:
/// no colored fill, text-only tabs, primary underline for the active tab.
///
/// Horizontal inset matches body content ([AppUiSizes.lg]) so the first tab
/// lines up with chips / cards below. The bottom hairline always spans the
/// full screen width (even when [visualSlotCount] shortens the tab strip).
///
/// Set [visualSlotCount] when fewer labels should keep the same slot width as a
/// fuller bar (e.g. Workout Sets/Programs as 2 of 4 equal slots).
class StandardTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<String> labels;
  final bool isScrollable;

  /// If set and greater than [labels.length], the tab bar width is
  /// `contentWidth * labels.length / visualSlotCount`, left-aligned.
  final int? visualSlotCount;

  const StandardTabAppBar({
    super.key,
    required this.controller,
    required this.labels,
    this.isScrollable = true,
    this.visualSlotCount,
  });

  @override
  Size get preferredSize => Size.fromHeight(preferredTabBarHeight);

  static double get preferredTabBarHeight => 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final dividerColor = Theme.of(context).dividerColor;

    final slots = visualSlotCount;
    final useSlots =
        slots != null && slots > labels.length && labels.isNotEmpty;

    // Non-scrollable equal slots when using visualSlotCount or filling the bar.
    final scrollable = useSlots ? false : isScrollable;

    final tabBar = TabBar(
      controller: controller,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: AppUiSizes.lg),
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColorPalette.textColor,
      unselectedLabelColor: AppColorPalette.grey700,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      tabs: [for (final label in labels) Tab(text: label)],
    );

    return AppBar(
      title: const SizedBox.shrink(),
      toolbarHeight: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: AppColorPalette.textColor,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(preferredTabBarHeight),
        // Force full width so the hairline isn't sized to the tab strip.
        child: SizedBox(
          width: double.infinity,
          height: preferredTabBarHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: dividerColor),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppUiSizes.lg,
                  ),
                  child: useSlots
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final slotCount = visualSlotCount!;
                            final width = constraints.maxWidth *
                                (labels.length / slotCount);
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: width,
                                child: tabBar,
                              ),
                            );
                          },
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: tabBar,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
