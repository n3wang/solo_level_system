import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// Outlined list row matching Sets exercise tiles: grey border, 12 radius,
/// optional top-right bookmark, optional badge beside it.
class OutlinedEntityTile extends StatelessWidget {
  const OutlinedEntityTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.footer,
    this.badge,
    this.belowSubtitle,
    this.isBookmarked = false,
    this.onBookmarkTap,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? footer;
  final Widget? badge;
  final Widget? belowSubtitle;
  final bool isBookmarked;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  static const double leadingSize = 60;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor =
        isDark ? AppColorPalette.grey400 : AppColorPalette.grey600;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: AppColorPalette.grey300),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        SizedBox(
                          width: leadingSize,
                          height: leadingSize,
                          child: leading,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (badge != null) ...[
                                  const SizedBox(width: 8),
                                  badge!,
                                  // Space for bookmark in the top-right
                                  if (onBookmarkTap != null)
                                    const SizedBox(width: 28),
                                ] else if (onBookmarkTap != null)
                                  const SizedBox(width: 28),
                              ],
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            if (belowSubtitle != null) belowSubtitle!,
                            if (footer != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  footer!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColorPalette.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onBookmarkTap != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onBookmarkTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                          color: isBookmarked
                              ? AppColorPalette.color2
                              : AppColorPalette.grey400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading art frame used by Sets tiles and game hub tiles.
class OutlinedEntityLeading extends StatelessWidget {
  const OutlinedEntityLeading({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark
            ? AppColorPalette.backgroundDarkSurface
            : AppColorPalette.white);
    return Container(
      width: OutlinedEntityTile.leadingSize,
      height: OutlinedEntityTile.leadingSize,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
        child: Center(child: child),
      ),
    );
  }
}
