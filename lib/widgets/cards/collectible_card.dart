import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_acquisition_service.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:sprite_sheets/sprite_sheets.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';

/// Icon for a card type wire string (or [CardType]).
IconData collectibleTypeIcon(String type) {
  switch (CardType.parse(type)) {
    case CardType.quote:
      return Icons.format_quote;
    case CardType.reward:
      return Icons.card_giftcard;
    case CardType.room:
      return Icons.weekend_outlined;
    case CardType.music:
      return Icons.music_note;
    case CardType.program:
      return Icons.list_alt;
    case CardType.exercise:
      return Icons.fitness_center;
    case CardType.guide:
      return Icons.help_outline;
    case CardType.option:
      return Icons.tune;
    case CardType.collection:
      return Icons.diamond_outlined;
  }
}

/// Category chips as icons only (reward create / filters feel).
IconData collectibleCategoryIcon(String category) {
  switch (category.trim().toLowerCase()) {
    case 'electronics':
      return Icons.devices;
    case 'entertainment':
      return Icons.sports_esports;
    case 'food':
      return Icons.restaurant;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'activities':
      return Icons.directions_run;
    case 'tools':
      return Icons.build_outlined;
    case 'books':
      return Icons.menu_book_outlined;
    case 'health':
      return Icons.favorite_outline;
    case 'travel':
      return Icons.flight_takeoff;
    case 'lofi':
    case 'music':
      return Icons.music_note;
    case 'room':
      return Icons.weekend_outlined;
    default:
      return Icons.category_outlined;
  }
}

const List<String> kRewardCategories = [
  'general',
  'electronics',
  'entertainment',
  'food',
  'shopping',
  'activities',
  'tools',
  'books',
  'health',
  'travel',
];

/// Catalog type filters for Cards hub (no `all` — pick a specific type).
const List<String> kCollectibleTypeFilters = [
  'quote',
  'collection',
  'reward',
  'room',
  'music',
  'program',
  'exercise',
  'guide',
  'option',
];

/// Special filter value for bookmarked cards (hub + overview).
const String kCollectibleBookmarkFilter = 'bookmarked';

/// Overview acquired list may still filter with `all` inside the week window.
const List<String> kCollectibleOverviewTypeFilters = [
  'all',
  kCollectibleBookmarkFilter,
  ...kCollectibleTypeFilters,
];

/// Whether unowned catalog art/copy should be shown in full (test/demo).
bool revealCollectibleContents(CatalogCard card, {bool acquiredReveal = false}) {
  if (acquiredReveal) return true;
  if (AppEnvironment.revealUnacquiredCardDetails) return true;
  return card.isAcquired;
}

/// Spoiler copy for locked cards (Pokemon TCG-style acquire-to-reveal).
String collectibleAcquirePrompt(CardType type) {
  switch (type) {
    case CardType.music:
      return 'Acquire to listen.';
    case CardType.quote:
      return 'Acquire to read.';
    case CardType.guide:
      return 'Acquire to unlock help.';
    case CardType.program:
    case CardType.exercise:
      return 'Acquire to unlock.';
    case CardType.room:
    case CardType.reward:
    case CardType.collection:
    case CardType.option:
      return 'Acquire to view.';
  }
}

/// Generic unrevealed-card art: same outlined help icon used as the type
/// fallback (large grey `?` in a circle).
class CollectibleMysteryArt extends StatelessWidget {
  final double size;

  const CollectibleMysteryArt({
    super.key,
    this.size = CollectibleCardLayout.tileArtSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.help_outline,
        size: size * 0.75,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Shared art for a [CatalogCard] (sprite, asset, file, or type icon).
class CollectibleCardArt extends StatelessWidget {
  final CatalogCard card;
  final double size;
  final String? overrideLocalImagePath;

  /// When false, shows [CollectibleMysteryArt] instead of real art.
  final bool revealContents;

  const CollectibleCardArt({
    super.key,
    required this.card,
    this.size = CollectibleCardLayout.tileArtSize,
    this.overrideLocalImagePath,
    this.revealContents = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!revealContents) {
      return CollectibleMysteryArt(size: size);
    }

    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      collectibleTypeIcon(card.typeWire),
      size: size * 0.75,
      color: scheme.onSurface.withValues(alpha: 0.5),
    );

    final local = overrideLocalImagePath ?? card.localImagePath;
    if (local != null && local.isNotEmpty && !kIsWeb) {
      final file = File(local);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      }
    }

    final index = card.imageIndex;
    if (index != null && index > 0) {
      return SpriteImage(sheet: 'motivation_64', index: index - 1, size: size);
    }

    final asset = card.imageAsset;
    if (asset != null && asset.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return fallback;
  }
}

/// Standard grid / overview tile. Type + category are **icons only**.
class CollectibleCardTile extends StatelessWidget {
  final CatalogCard card;
  final VoidCallback? onTap;
  final int? availablePoints;
  final String? overrideLocalImagePath;

  /// Always show real art / type icons (e.g. create-reward preview).
  final bool forceRevealContents;

  const CollectibleCardTile({
    super.key,
    required this.card,
    this.onTap,
    this.availablePoints,
    this.overrideLocalImagePath,
    this.forceRevealContents = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAfford = availablePoints == null
        ? true
        : availablePoints! >= card.pointsCost;
    final revealed =
        forceRevealContents || revealCollectibleContents(card);

    return InkWell(
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppUiSizes.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.6),
          ),
          color: scheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (revealed)
                  Icon(
                    collectibleTypeIcon(card.typeWire),
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  )
                else
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                const Spacer(),
                if (revealed)
                  Icon(
                    collectibleCategoryIcon(card.category),
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                if (!card.isAcquired) ...[
                  const SizedBox(width: AppUiSizes.xs),
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
                if (card.isBookmarked) ...[
                  const SizedBox(width: AppUiSizes.xs),
                  Icon(
                    Icons.bookmark,
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
              ],
            ),
            Expanded(
              child: Center(
                child: CollectibleCardArt(
                  card: card,
                  size: CollectibleCardLayout.tileArtSize,
                  overrideLocalImagePath: overrideLocalImagePath,
                  revealContents: revealed,
                ),
              ),
            ),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppUiSizes.xxs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                card.isAcquired
                    ? (card.acquisitionCount > 1
                          ? 'owned x${card.acquisitionCount}'
                          : 'owned')
                    : '${card.pointsCost}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: card.isAcquired
                      ? scheme.onSurface.withValues(alpha: 0.65)
                      : canAfford
                      ? scheme.primary
                      : scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the shared collectible detail dialog (music play, room visuals, etc.).
///
/// Set [acquiredReveal] for the post-session celebration layout: "Acquired"
/// banner above, rarity + copy count below, no buy action.
Future<void> showCollectibleCardDetail({
  required BuildContext context,
  required CatalogCard card,
  required UserProgressModel userProgress,
  bool allowAcquire = true,
  bool acquiredReveal = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => CollectibleCardDetailDialog(
      card: card,
      userProgress: userProgress,
      allowAcquire: acquiredReveal ? false : allowAcquire,
      acquiredReveal: acquiredReveal,
    ),
  );
}

/// Shows each dropped card with the acquired-reveal presentation, in order.
///
/// Prefer [showAcquiredCardToasts] for session loot (non-blocking). This full
/// modal sequence remains for callers that want an immediate reveal.
Future<void> showAcquiredCardReveals({
  required BuildContext context,
  required List<CatalogCard> cards,
  required UserProgressModel userProgress,
}) async {
  for (final card in cards) {
    if (!context.mounted) return;
    await showCollectibleCardDetail(
      context: context,
      card: card,
      userProgress: userProgress,
      acquiredReveal: true,
    );
  }
}

class CollectibleCardDetailDialog extends StatefulWidget {
  final CatalogCard card;
  final UserProgressModel userProgress;
  final bool allowAcquire;
  final bool acquiredReveal;

  const CollectibleCardDetailDialog({
    super.key,
    required this.card,
    required this.userProgress,
    this.allowAcquire = true,
    this.acquiredReveal = false,
  });

  @override
  State<CollectibleCardDetailDialog> createState() =>
      _CollectibleCardDetailDialogState();
}

class _CollectibleCardDetailDialogState
    extends State<CollectibleCardDetailDialog> {
  AudioPlayer? _previewPlayer;
  bool _isPreviewing = false;
  int _visualIndex = 0;
  late List<String> _quoteOptions;
  late String _currentQuote;
  String _activeQuotePanel = '';
  late final TextEditingController _quoteEditorController;
  late final TextEditingController _descriptionEditorController;
  late String _currentDescription;
  late bool _isBookmarked;

  CatalogCard get card => widget.card;

  @override
  void initState() {
    super.initState();
    _isBookmarked = card.isBookmarked;
    _quoteOptions = _quotesFor(card);
    _currentQuote = _quoteOptions.isNotEmpty
        ? _quoteOptions.first
        : card.description;
    _currentDescription = card.description;
    _quoteEditorController = TextEditingController(
      text: _quoteOptions.join('\n'),
    );
    _descriptionEditorController = TextEditingController(
      text: card.description,
    );
  }

  @override
  void dispose() {
    _previewPlayer?.dispose();
    _quoteEditorController.dispose();
    _descriptionEditorController.dispose();
    super.dispose();
  }

  List<String> _quotesFor(CatalogCard c) {
    final item = c.sourceItem;
    if (item == null || c.type != CardType.quote) return const [];
    final quotes = <String>[];
    final raw = item.metadata['quotes'];
    if (raw is List) {
      for (final q in raw) {
        final text = q.toString().trim();
        if (text.isNotEmpty) quotes.add(text);
      }
    }
    final single = item.quoteText?.trim();
    if (quotes.isEmpty && single != null && single.isNotEmpty) {
      quotes.add(single);
    }
    return quotes;
  }

  String? get _musicFilename {
    final target = card.unlockTargetId;
    if (card.type != CardType.music ||
        target == null ||
        !target.startsWith('music:')) {
      return null;
    }
    final name = target.substring('music:'.length).trim();
    return name.isEmpty ? null : name;
  }

  List<String> get _roomVisuals {
    if (card.type != CardType.room) return const [];
    return card.visuals;
  }

  Future<void> _playPreview(String filename) async {
    final player = _previewPlayer ??= AudioPlayer();
    await player.stop();
    await player.play(AssetSource('lofi/$filename'));
  }

  Future<void> _stopPreview() async {
    await _previewPlayer?.stop();
  }

  Future<bool> _acquire() async {
    final hasExisting = card.sourceItem != null
        ? card.sourceItem!.hasAnyAcquisition
        : card.sourceReward != null && card.sourceReward!.timesPurchased > 0;
    if (hasExisting) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Acquire again?'),
          content: Text(
            'You already acquired "${card.title}". Acquire again for ${card.pointsCost} points?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Acquire again'),
            ),
          ],
        ),
      );
      if (ok != true) return false;
    }

    final result = card.sourceItem != null
        ? await CardAcquisitionService.acquireCard(
            card.sourceItem!,
            widget.userProgress,
          )
        : CardAcquisitionService.acquireReward(
            card.sourceReward!,
            widget.userProgress,
          );

    if (!mounted) return false;
    showAppSnack(
      context,
      text: result.message,
    );
    return result.success;
  }

  Future<void> _saveQuotes() async {
    final item = card.sourceItem;
    if (item == null) return;
    final lines = _quoteEditorController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final editedDescription = _descriptionEditorController.text.trim();
    final metadata = Map<String, dynamic>.from(item.metadata);
    metadata['quotes'] = lines;
    item.metadata = metadata;
    item.quoteText = lines.first;
    if (editedDescription.isNotEmpty) {
      item.description = editedDescription;
    }
    await item.save();
    setState(() {
      _quoteOptions = lines;
      _currentQuote = lines.first;
      if (editedDescription.isNotEmpty) {
        _currentDescription = editedDescription;
      }
      _quoteEditorController.text = lines.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAfford =
        widget.userProgress.availablePoints >= card.pointsCost;
    final canPurchaseReward =
        card.sourceReward == null ? true : card.sourceReward!.canBePurchased;
    final canAttemptAcquire =
        widget.allowAcquire && canAfford && canPurchaseReward;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardBody = _buildCardBody(
      scheme: scheme,
      canAfford: canAfford,
      canPurchaseReward: canPurchaseReward,
      canAttemptAcquire: canAttemptAcquire,
      screenHeight: screenHeight,
    );

    if (!widget.acquiredReveal) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(AppUiSizes.lg),
        content: cardBody,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppUiSizes.lg,
        vertical: AppUiSizes.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _revealBanner(
            context,
            child: Text(
              'Acquired',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppUiSizes.sm),
          Material(
            color: scheme.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(AppUiSizes.modalRadius),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppUiSizes.lg),
              child: cardBody,
            ),
          ),
          const SizedBox(height: AppUiSizes.sm),
          _revealBanner(
            context,
            child: Text(
              '${card.rarity.wire} [${card.acquisitionCount.clamp(1, 1 << 20)}]',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revealBanner(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      child: Container(
        width: CollectibleCardLayout.detailModalWidth * 0.55,
        padding: const EdgeInsets.symmetric(
          horizontal: AppUiSizes.md,
          vertical: AppUiSizes.xs,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.55),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCardBody({
    required ColorScheme scheme,
    required bool canAfford,
    required bool canPurchaseReward,
    required bool canAttemptAcquire,
    required double screenHeight,
  }) {
    final revealed = revealCollectibleContents(
      card,
      acquiredReveal: widget.acquiredReveal,
    );
    final isQuote = card.type == CardType.quote;
    final visuals = revealed ? _roomVisuals : const <String>[];
    final musicFile = revealed ? _musicFilename : null;
    final heightFactor = widget.acquiredReveal
        ? CollectibleCardLayout.detailModalHeightFactor * 0.82
        : CollectibleCardLayout.detailModalHeightFactor;
    final bodyCopy = revealed
        ? (isQuote ? _currentQuote : _currentDescription)
        : collectibleAcquirePrompt(card.type);

    return SizedBox(
      width: CollectibleCardLayout.detailModalWidth,
      height: screenHeight * heightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (revealed) ...[
                Icon(collectibleTypeIcon(card.typeWire), size: 20),
                const SizedBox(width: AppUiSizes.sm),
              ],
              Expanded(
                child: Text(
                  card.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () async {
                  final next = await CardRepository.toggleBookmark(card);
                  if (!mounted) return;
                  setState(() => _isBookmarked = next);
                },
              ),
              if (revealed)
                Icon(
                  collectibleCategoryIcon(card.category),
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
            ],
          ),
          const SizedBox(height: AppUiSizes.md),
          Center(
            child: visuals.isNotEmpty
                ? _buildRoomVisualPreview(visuals, scheme)
                : CollectibleCardArt(
                    card: card,
                    size: CollectibleCardLayout.modalArtSize,
                    revealContents: revealed,
                  ),
          ),
          if (visuals.length > 1) ...[
            const SizedBox(height: AppUiSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous visual',
                  onPressed: () {
                    setState(() {
                      _visualIndex =
                          (_visualIndex - 1 + visuals.length) % visuals.length;
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_visualIndex + 1} / ${visuals.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                IconButton(
                  tooltip: 'Next visual',
                  onPressed: () {
                    setState(() {
                      _visualIndex = (_visualIndex + 1) % visuals.length;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppUiSizes.sm),
          Text(
            'Cost: ${card.pointsCost} points',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: card.isAcquired
                  ? scheme.tertiary
                  : canAfford
                  ? scheme.primary
                  : scheme.error,
            ),
          ),
          if (revealed && isQuote) ...[
            const SizedBox(height: AppUiSizes.sm),
            _buildQuoteControls(scheme),
          ],
          const SizedBox(height: AppUiSizes.sm),
          if (!revealed || !isQuote || _activeQuotePanel.isEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  bodyCopy,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: revealed ? FontStyle.normal : FontStyle.italic,
                    color: revealed
                        ? null
                        : scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
            )
          else
            Expanded(child: _buildQuotePanelBody(scheme)),
          if (musicFile != null) ...[
            const SizedBox(height: AppUiSizes.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (_isPreviewing) {
                    await _stopPreview();
                    setState(() => _isPreviewing = false);
                  } else {
                    await _playPreview(musicFile);
                    setState(() => _isPreviewing = true);
                  }
                },
                icon: Icon(
                  _isPreviewing
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                ),
                label: Text(_isPreviewing ? 'Stop' : 'Play'),
              ),
            ),
          ] else if (!revealed && card.type == CardType.music) ...[
            const SizedBox(height: AppUiSizes.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  showAppSnack(
                    context,
                    text: collectibleAcquirePrompt(CardType.music),
                  );
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Play'),
              ),
            ),
          ],
          if (revealed &&
              card.type == CardType.room &&
              (card.bundledMusicCount > 0 || visuals.isNotEmpty)) ...[
            const SizedBox(height: AppUiSizes.xs),
            Text(
              [
                if (card.bundledMusicCount > 0)
                  '${card.bundledMusicCount} track${card.bundledMusicCount == 1 ? '' : 's'}',
                if (visuals.isNotEmpty)
                  '${visuals.length} visual${visuals.length == 1 ? '' : 's'}',
              ].join(' · '),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: AppUiSizes.lg),
          if (widget.allowAcquire ||
              (card.type == CardType.reward && !widget.acquiredReveal))
            Row(
              children: [
                if (card.type == CardType.reward && !widget.acquiredReveal)
                  DestructiveActionButton(
                    text: 'Delete',
                    onPressed: _deleteRewardCard,
                  ),
                const Spacer(),
                if (widget.allowAcquire)
                  PrimaryActionButton(
                    text: !canAfford
                        ? 'Not enough'
                        : !canPurchaseReward
                        ? 'Unavailable'
                        : 'acquire [${card.pointsCost}pts]',
                    onPressed: !canAttemptAcquire
                        ? null
                        : () async {
                            final ok = await _acquire();
                            if (!mounted || !ok) return;
                            await _stopPreview();
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _deleteRewardCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reward?'),
        content: Text('Delete "${card.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (card.sourceReward != null) {
      await card.sourceReward!.delete();
    } else if (card.sourceItem != null) {
      await card.sourceItem!.delete();
    }

    await _stopPreview();
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, text: 'Reward deleted');
  }

  Widget _buildRoomVisualPreview(List<String> visuals, ColorScheme scheme) {
    final path = visuals[_visualIndex.clamp(0, visuals.length - 1)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      child: Image.asset(
        path,
        width: CollectibleCardLayout.modalArtSize * 1.35,
        height: CollectibleCardLayout.modalArtSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CollectibleCardArt(
          card: card,
          size: CollectibleCardLayout.modalArtSize,
          revealContents: true,
        ),
      ),
    );
  }

  Widget _buildQuoteControls(ColorScheme scheme) {
    final showRandom = _quoteOptions.length > 1;
    return Row(
      children: [
        if (showRandom)
          IconButton(
            tooltip: 'Random quote',
            onPressed: () {
              final candidates = _quoteOptions
                  .where((q) => q != _currentQuote)
                  .toList();
              if (candidates.isEmpty) return;
              setState(() {
                _currentQuote =
                    candidates[Random().nextInt(candidates.length)];
                _activeQuotePanel = '';
              });
            },
            icon: const Icon(Icons.casino_outlined),
          ),
        IconButton(
          tooltip: 'Next quote',
          onPressed: _quoteOptions.isEmpty
              ? null
              : () {
                  final i = _quoteOptions.indexOf(_currentQuote);
                  final next = i < 0 ? 0 : (i + 1) % _quoteOptions.length;
                  setState(() {
                    _currentQuote = _quoteOptions[next];
                    _activeQuotePanel = '';
                  });
                },
          icon: const Icon(Icons.skip_next_outlined),
        ),
        IconButton(
          tooltip: 'Show all quotes',
          onPressed: _quoteOptions.isEmpty
              ? null
              : () {
                  setState(() {
                    _activeQuotePanel = _activeQuotePanel == 'show_all'
                        ? ''
                        : 'show_all';
                  });
                },
          icon: Icon(
            Icons.view_list_outlined,
            color: _activeQuotePanel == 'show_all' ? scheme.primary : null,
          ),
        ),
        IconButton(
          tooltip: 'Edit quotes',
          onPressed: card.sourceItem == null
              ? null
              : () {
                  setState(() {
                    _activeQuotePanel =
                        _activeQuotePanel == 'edit' ? '' : 'edit';
                  });
                },
          icon: Icon(
            Icons.edit_outlined,
            color: _activeQuotePanel == 'edit' ? scheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuotePanelBody(ColorScheme scheme) {
    if (_activeQuotePanel == 'show_all') {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUiSizes.sm,
            vertical: AppUiSizes.xs,
          ),
          itemCount: _quoteOptions.length,
          separatorBuilder: (_, __) => Divider(
            height: AppUiSizes.md,
            color: scheme.outline.withValues(alpha: 0.32),
          ),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppUiSizes.xs),
              child: Text(
                '${index + 1}. ${_quoteOptions[index]}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          },
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _quoteEditorController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'One quote per line',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppUiSizes.xs),
          TextField(
            controller: _descriptionEditorController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveQuotes,
              child: const Text('Save quotes'),
            ),
          ),
        ],
      ),
    );
  }
}
