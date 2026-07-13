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
        child: _AcquiredCardToastBubble(
          card: card,
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

class _AcquiredCardToastBubble extends StatelessWidget {
  final CatalogCard card;
  final VoidCallback onTap;

  const _AcquiredCardToastBubble({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      color: scheme.surface,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        child: Container(
          width: 118,
          padding: const EdgeInsets.all(AppUiSizes.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
            border: Border.all(color: scheme.tertiary.withValues(alpha: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acquired',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppUiSizes.xxs),
              AspectRatio(
                aspectRatio: CollectibleCardLayout.aspectRatio,
                child: CollectibleCardTile(card: card),
              ),
              const SizedBox(height: AppUiSizes.xxs),
              Text(
                '${card.rarity.wire} [${card.acquisitionCount.clamp(1, 1 << 20)}]',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
