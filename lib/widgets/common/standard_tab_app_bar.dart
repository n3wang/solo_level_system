// lib/widgets/common/standard_tab_app_bar.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Shared top tab bar matching the Stats (Overview) pattern:
/// no colored fill, text-only tabs, primary underline for the active tab.
class StandardTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<String> labels;
  final bool isScrollable;

  const StandardTabAppBar({
    super.key,
    required this.controller,
    required this.labels,
    this.isScrollable = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(preferredTabBarHeight);

  static double get preferredTabBarHeight => 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return AppBar(
      title: const SizedBox.shrink(),
      toolbarHeight: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: AppColorPalette.textColor,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(preferredTabBarHeight),
        child: TabBar(
          controller: controller,
          isScrollable: isScrollable,
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
        ),
      ),
    );
  }
}
