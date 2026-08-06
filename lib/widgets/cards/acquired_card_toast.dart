import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';

/// Queues non-blocking bottom-right acquisition toasts.
///
/// Each toast auto-dismisses after [autoDismiss] unless tapped, which opens
/// the acquired-card modal. Cards are shown one at a time to avoid interruption.
Future<void> showAcquiredCardToasts({
  required BuildContext context,
  required List<CatalogCard> cards,
  required UserProgressModel userProgress,
  Duration autoDismiss = const Duration(seconds: 3),
}) async {
  for (final card in cards) {
    if (!context.mounted) return;
    await showAcquiredCardToast(
      context: context,
      card: card,
      userProgress: userProgress,
      autoDismiss: autoDismiss,
    );
  }
}

/// Single bottom-right mini card toast for one acquisition.
Future<void> showAcquiredCardToast({
  required BuildContext context,
  required CatalogCard card,
  required UserProgressModel userProgress,
  Duration autoDismiss = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    // No overlay (e.g. tests) — fall back to the full modal.
    return showCollectibleCardDetail(
      context: context,
      card: card,
      userProgress: userProgress,
      acquiredReveal: true,
    );
  }

  final completer = Completer<void>();
  late OverlayEntry entry;
  Timer? timer;
  var removed = false;

  Future<void> finish() async {
    if (removed) return;
    removed = true;
    timer?.cancel();
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> openDetail() async {
    if (removed) return;
    removed = true;
    timer?.cancel();
    entry.remove();
    if (context.mounted) {
      await showCollectibleCardDetail(
        context: context,
        card: card,
        userProgress: userProgress,
        acquiredReveal: true,
      );
    }
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return Positioned(
        right: AppUiSizes.lg,
        bottom: bottomInset + AppUiSizes.xxl + AppUiSizes.lg,
        child: CardRewardMiniature(
          card: card,
          label: 'Acquired',
          subtitle:
              '${card.rarity.wire} [${card.acquisitionCount.clamp(1, 1 << 20)}]',
          onTap: openDetail,
        ),
      );
    },
  );

  overlay.insert(entry);
  timer = Timer(autoDismiss, () {
    unawaited(finish());
  });

  return completer.future;
}

/// Compact collectible card chrome used by acquisition toasts and pending
/// Rogue challenge badges (bottom-right of the pomodoro screen).
class CardRewardMiniature extends StatelessWidget {
  final CatalogCard card;
  final String? label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? footer;
  final double width;
  final bool forceRevealContents;

  const CardRewardMiniature({
    super.key,
    required this.card,
    this.label,
    this.subtitle,
    this.onTap,
    this.footer,
    this.width = 118,
    this.forceRevealContents = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppUiSizes.xxs),
        ],
        AspectRatio(
          aspectRatio: CollectibleCardLayout.aspectRatio,
          child: CollectibleCardTile(
            card: card,
            forceRevealContents: forceRevealContents,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: AppUiSizes.xxs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final paddedCard = Container(
      width: width,
      padding: const EdgeInsets.all(AppUiSizes.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.7)),
        color: scheme.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          onTap == null
              ? cardBody
              : InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  child: cardBody,
                ),
          if (footer != null) ...[
            const SizedBox(height: AppUiSizes.xs),
            footer!,
          ],
        ],
      ),
    );

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      color: scheme.surface,
      shadowColor: Colors.black54,
      child: paddedCard,
    );
  }
}
