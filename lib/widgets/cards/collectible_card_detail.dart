import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_acquisition_service.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_art.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_chrome.dart';
import 'package:solo_level_system/widgets/cards/collectible_card_meta.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/widgets/common/button_components.dart';

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

  /// When true, hide place / year catalog facts (e.g. Chrono Atlas pre-confirm).
  bool hideCatalogFacts = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => CollectibleCardDetailDialog(
      card: card,
      userProgress: userProgress,
      allowAcquire: acquiredReveal ? false : allowAcquire,
      acquiredReveal: acquiredReveal,
      hideCatalogFacts: hideCatalogFacts,
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
  final bool hideCatalogFacts;

  const CollectibleCardDetailDialog({
    super.key,
    required this.card,
    required this.userProgress,
    this.allowAcquire = true,
    this.acquiredReveal = false,
    this.hideCatalogFacts = false,
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
  late List<PhyEntry> _phyEntries;
  late PhyEntry _currentEntry;
  String _activeQuotePanel = '';
  late final TextEditingController _quoteEditorController;
  late final TextEditingController _descriptionEditorController;
  late String _currentDescription;
  late bool _isBookmarked;
  bool _showDescription = false;

  CatalogCard get card => widget.card;

  @override
  void initState() {
    super.initState();
    _isBookmarked = card.isBookmarked;
    _phyEntries = _entriesFor(card);
    _currentEntry = _phyEntries.isNotEmpty
        ? _phyEntries.first
        : PhyEntry(text: card.description);
    _currentDescription = card.description;
    _quoteEditorController = TextEditingController(
      text: _phyEntries.map((e) => e.text).join('\n'),
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

  List<PhyEntry> _entriesFor(CatalogCard c) {
    final item = c.sourceItem;
    if (item == null || c.type != CardType.phy) return const [];
    final entries = <PhyEntry>[];
    // Try new 'entries' key first, fall back to legacy 'quotes'
    final raw = item.metadata['entries'] ?? item.metadata['quotes'];
    if (raw is List) {
      for (final q in raw) {
        final entry = PhyEntry.fromRaw(q);
        if (entry.text.isNotEmpty) entries.add(entry);
      }
    }
    final single = item.quoteText?.trim();
    if (entries.isEmpty && single != null && single.isNotEmpty) {
      entries.add(PhyEntry(text: single));
    }
    return entries;
  }

  /// Looks up a linked card by ID from the same source box.
  CatalogCard? _getLinkedCard(String? cardId) {
    if (cardId == null || cardId.isEmpty) return null;
    final sourceItem = card.sourceItem;
    if (sourceItem == null) return null;
    final box = sourceItem.box as Box<CardModel>?;
    if (box == null) return null;
    for (final item in box.values) {
      if (item.id == cardId) {
        return CardRepository.fromCardModel(item);
      }
    }
    return null;
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
    await player.play(AssetSource('audio/lofi/$filename'));
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
    showAppSnack(context, text: result.message);
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
    // Preserve linked card associations when saving text-only edits
    final newEntries = <dynamic>[];
    for (var i = 0; i < lines.length; i++) {
      final existingLink = i < _phyEntries.length
          ? _phyEntries[i].linkedCardId
          : null;
      final entry = PhyEntry(text: lines[i], linkedCardId: existingLink);
      newEntries.add(entry.toStorage());
    }
    metadata['entries'] = newEntries;
    metadata.remove('quotes'); // Remove legacy key
    item.metadata = metadata;
    item.quoteText = lines.first;
    if (editedDescription.isNotEmpty) {
      item.description = editedDescription;
    }
    await item.save();
    setState(() {
      _phyEntries = newEntries.map((e) => PhyEntry.fromRaw(e)).toList();
      _currentEntry = _phyEntries.first;
      if (editedDescription.isNotEmpty) {
        _currentDescription = editedDescription;
      }
      _quoteEditorController.text = lines.join('\n');
    });
  }

  void _toggleDescription() {
    if (_activeQuotePanel == 'edit') return;
    setState(() {
      _showDescription = !_showDescription;
      if (!_showDescription) _activeQuotePanel = '';
    });
  }

  Size _detailCardSize(BuildContext context, {required double extraBelow}) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final side = max(
      CollectibleCardLayout.detailCardMinMargin,
      screenW * (1 - CollectibleCardLayout.detailCardWidthFraction) / 2,
    );
    final maxWidth = (screenW - media.padding.horizontal - side * 4)
        .clamp(176.0, screenW)
        .toDouble();
    final maxHeight =
        (screenH - media.padding.vertical - AppUiSizes.md * 2 - extraBelow)
            .clamp(176.0 / CollectibleCardLayout.modalAspectRatio, screenH)
            .toDouble();
    final widthFromHeight = maxHeight * CollectibleCardLayout.modalAspectRatio;
    final width = min(maxWidth, widthFromHeight).toDouble();
    return Size(width, width / CollectibleCardLayout.modalAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAfford = widget.userProgress.availablePoints >= card.pointsCost;
    final canPurchaseReward = card.sourceReward == null
        ? true
        : card.sourceReward!.canBePurchased;
    final canAttemptAcquire =
        widget.allowAcquire && canAfford && canPurchaseReward;
    final revealed = revealCollectibleContents(
      card,
      acquiredReveal: widget.acquiredReveal,
    );
    final isPhy = card.type == CardType.phy;
    final visuals = revealed ? _roomVisuals : const <String>[];
    final musicFile = revealed ? _musicFilename : null;
    final fullBleed =
        revealed && CollectibleCardLayout.isFullBleedAsset(card.imageAsset);
    final showAcquire = widget.allowAcquire;
    final showDelete = card.type == CardType.reward && !widget.acquiredReveal;
    final showMusic =
        musicFile != null || (!revealed && card.type == CardType.music);

    final cardSize = _detailCardSize(
      context,
      extraBelow:
          (showAcquire ? 56.0 : 0) +
          (showDelete ? 48.0 : 0) +
          (showMusic ? 52.0 : 0) +
          (widget.acquiredReveal ? 88.0 : 0),
    );

    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final horizontalInset = max(
      CollectibleCardLayout.detailCardMinMargin,
      (screen.width - cardSize.width) / 2,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.fromLTRB(
        horizontalInset,
        padding.top + AppUiSizes.sm,
        horizontalInset,
        padding.bottom + AppUiSizes.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.acquiredReveal) ...[
                _revealBanner(
                  context,
                  width: cardSize.width * 0.55,
                  child: Text(
                    'Acquired',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppUiSizes.sm),
              ],
              _buildTradingCard(
                scheme: scheme,
                size: cardSize,
                revealed: revealed,
                isPhy: isPhy,
                visuals: visuals,
                fullBleed: fullBleed,
              ),
              if (showMusic) ...[
                const SizedBox(height: AppUiSizes.sm),
                _buildMusicButton(scheme, musicFile),
              ],
              if (showAcquire || showDelete) ...[
                const SizedBox(height: AppUiSizes.md),
                if (showAcquire)
                  SizedBox(
                    width: cardSize.width * 0.92,
                    child: PrimaryActionButton(
                      text: !canAfford
                          ? 'Not enough'
                          : !canPurchaseReward
                          ? 'Unavailable'
                          : 'acquire [${card.pointsCost}pts]',
                      onPressed: !canAttemptAcquire
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final ok = await _acquire();
                              if (!mounted || !ok) return;
                              await _stopPreview();
                              if (!mounted) return;
                              navigator.pop();
                            },
                    ),
                  ),
                if (showDelete) ...[
                  const SizedBox(height: AppUiSizes.sm),
                  DestructiveActionButton(
                    text: 'Delete',
                    onPressed: _deleteRewardCard,
                  ),
                ],
              ],
              if (widget.acquiredReveal) ...[
                const SizedBox(height: AppUiSizes.sm),
                _revealBanner(
                  context,
                  width: cardSize.width * 0.55,
                  child: Text(
                    '${card.rarity.wire} [${card.acquisitionCount.clamp(1, 1 << 20)}]',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _revealBanner(
    BuildContext context, {
    required Widget child,
    double? width,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      child: Container(
        width: width ?? CollectibleCardLayout.detailModalWidth * 0.55,
        padding: const EdgeInsets.symmetric(
          horizontal: AppUiSizes.md,
          vertical: AppUiSizes.xs,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildTradingCard({
    required ColorScheme scheme,
    required Size size,
    required bool revealed,
    required bool isPhy,
    required List<String> visuals,
    required bool fullBleed,
  }) {
    final linkedCard = isPhy && revealed
        ? _getLinkedCard(_currentEntry.linkedCardId)
        : null;
    final radius = BorderRadius.circular(AppUiSizes.modalRadius);
    final lightBleed =
        fullBleed && CollectibleCardLayout.isPngAsset(card.imageAsset);
    final iconColor = fullBleed && !lightBleed
        ? Colors.white
        : scheme.onSurface;

    return Material(
      color: fullBleed
          ? (lightBleed ? Colors.white : Colors.black)
          : scheme.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.85),
          width: AppUiSizes.mediumBorderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: InkWell(
          onTap: _toggleDescription,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fullBleed)
                _buildFullBleedFace(revealed: revealed, visuals: visuals)
              else
                Opacity(
                  opacity: _showDescription ? 0.28 : 1,
                  child: _buildSquareFace(
                    scheme: scheme,
                    revealed: revealed,
                    visuals: visuals,
                    linkedCard: linkedCard,
                  ),
                ),
              if (_showDescription)
                _buildDescriptionOverlay(
                  scheme: scheme,
                  revealed: revealed,
                  isPhy: isPhy,
                  visuals: visuals,
                ),
              if (fullBleed && !_showDescription)
                _buildFullBleedPills(revealed: revealed),
              if (fullBleed && _showDescription)
                Positioned(
                  top: AppUiSizes.sm,
                  left: AppUiSizes.md,
                  right: 72,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: CollectibleCardTitlePill(card.title),
                  ),
                ),
              Positioned(
                top: AppUiSizes.sm,
                right: AppUiSizes.sm,
                child: _buildTopActions(scheme, revealed, chip: fullBleed),
              ),
              if (visuals.length > 1) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      tooltip: 'Previous visual',
                      color: iconColor,
                      onPressed: () {
                        setState(() {
                          _visualIndex =
                              (_visualIndex - 1 + visuals.length) %
                              visuals.length;
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      tooltip: 'Next visual',
                      color: iconColor,
                      onPressed: () {
                        setState(() {
                          _visualIndex = (_visualIndex + 1) % visuals.length;
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullBleedFace({
    required bool revealed,
    required List<String> visuals,
  }) {
    if (visuals.isNotEmpty) {
      return _buildRoomVisualPreview(visuals, fullBleed: true);
    }
    return CollectibleCardArt(
      card: card,
      expand: true,
      revealContents: revealed,
    );
  }

  Widget _buildSquareFace({
    required ColorScheme scheme,
    required bool revealed,
    required List<String> visuals,
    required CatalogCard? linkedCard,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad =
            constraints.maxWidth * CollectibleCardLayout.artMarginFraction;
        final innerWidth = constraints.maxWidth - pad * 2;
        const iconSpace = 32.0;
        const reservedText = 118.0;
        final maxArtHeight =
            (constraints.maxHeight -
                    iconSpace -
                    reservedText -
                    AppUiSizes.sm * 2)
                .clamp(72.0, innerWidth);
        final artSize = min(innerWidth, maxArtHeight);
        return Padding(
          padding: EdgeInsets.fromLTRB(pad, AppUiSizes.sm, pad, AppUiSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: iconSpace),
              Center(
                child: SizedBox(
                  width: artSize,
                  height: artSize,
                  child: linkedCard != null
                      ? FittedBox(
                          child: _buildDualCardArt(card, linkedCard, revealed),
                        )
                      : visuals.isNotEmpty
                      ? _buildRoomVisualPreview(visuals, fullBleed: false)
                      : CollectibleCardArt(
                          card: card,
                          expand: true,
                          revealContents: revealed,
                          borderRadius: BorderRadius.circular(
                            CollectibleCardLayout.artRadius,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppUiSizes.sm),
              Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (revealed &&
                  !widget.hideCatalogFacts &&
                  card.hasCatalogFacts) ...[
                const SizedBox(height: AppUiSizes.xs),
                _buildCompactFacts(scheme),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescriptionOverlay({
    required ColorScheme scheme,
    required bool revealed,
    required bool isPhy,
    required List<String> visuals,
  }) {
    final bodyCopy = revealed
        ? (isPhy ? _currentEntry.text : _currentDescription)
        : collectibleAcquirePrompt(card.type);
    final roomMeta =
        revealed &&
            card.type == CardType.room &&
            (card.bundledMusicCount > 0 || visuals.isNotEmpty)
        ? [
            if (card.bundledMusicCount > 0)
              '${card.bundledMusicCount} track${card.bundledMusicCount == 1 ? '' : 's'}',
            if (visuals.isNotEmpty)
              '${visuals.length} visual${visuals.length == 1 ? '' : 's'}',
          ].join(' · ')
        : null;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppUiSizes.md,
          48,
          AppUiSizes.md,
          AppUiSizes.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppUiSizes.md),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: DefaultTextStyle(
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (revealed && isPhy) _buildQuoteControls(scheme),
                    Expanded(
                      child: revealed && isPhy && _activeQuotePanel.isNotEmpty
                          ? _buildQuotePanelBody(scheme)
                          : SingleChildScrollView(
                              child: CollectibleDescriptionText(
                                bodyCopy,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontStyle: revealed
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                              ),
                            ),
                    ),
                    if (roomMeta != null) ...[
                      const SizedBox(height: AppUiSizes.xs),
                      Text(
                        roomMeta,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullBleedPills({required bool revealed}) {
    final category = card.category.trim();
    return Positioned(
      left: AppUiSizes.md,
      right: AppUiSizes.md,
      bottom: AppUiSizes.md,
      child: Wrap(
        spacing: AppUiSizes.xs,
        runSpacing: AppUiSizes.xs,
        children: [
          CollectibleCardTitlePill(card.title),
          if (revealed && !widget.hideCatalogFacts && category.isNotEmpty)
            CollectibleCardTitlePill(category, emphasis: true),
        ],
      ),
    );
  }

  Widget _buildTopActions(
    ColorScheme scheme,
    bool revealed, {
    required bool chip,
  }) {
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 20,
          ),
          onPressed: () async {
            final next = await CardRepository.toggleBookmark(card);
            if (!mounted) return;
            setState(() => _isBookmarked = next);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppUiSizes.xs),
          child: Icon(
            revealed
                ? collectibleCategoryIcon(card.category)
                : Icons.lock_outline,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
    if (!chip) return icons;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: icons,
    );
  }

  Widget _buildMusicButton(ColorScheme scheme, String? musicFile) {
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
      child: musicFile != null
          ? OutlinedButton.icon(
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
            )
          : OutlinedButton.icon(
              onPressed: () {
                showAppSnack(
                  context,
                  text: collectibleAcquirePrompt(CardType.music),
                );
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Play'),
            ),
    );
  }

  Widget _buildCompactFacts(ColorScheme scheme) {
    final muted = scheme.onSurface.withValues(alpha: 0.72);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: muted,
      fontWeight: FontWeight.w600,
    );

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppUiSizes.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: AppUiSizes.xs),
            Expanded(
              child: Text(
                '$label: $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      );
    }

    final category = card.category.trim();
    final place = card.hasPlaceLabel ? card.placeLabel!.trim() : null;
    final yearLine = card.displayYearLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty)
          row(collectibleCategoryIcon(category), 'Category', category),
        if (place != null) row(Icons.place_outlined, 'Place', place),
        if (yearLine != null)
          row(Icons.calendar_today_outlined, 'Year', yearLine),
      ],
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

  Widget _buildDualCardArt(
    CatalogCard phyCard,
    CatalogCard linkedCard,
    bool revealed,
  ) {
    const dualSize = CollectibleCardLayout.modalArtSize * 0.65;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CollectibleCardArt(
          card: phyCard,
          size: dualSize,
          revealContents: revealed,
        ),
        const SizedBox(width: AppUiSizes.md),
        Column(
          children: [
            CollectibleCardArt(
              card: linkedCard,
              size: dualSize,
              revealContents: true,
            ),
            const SizedBox(height: AppUiSizes.xs),
            Text(
              linkedCard.title,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomVisualPreview(
    List<String> visuals, {
    required bool fullBleed,
  }) {
    final path = visuals[_visualIndex.clamp(0, visuals.length - 1)];
    Widget image = Image.asset(
      path,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          CollectibleCardArt(card: card, expand: true, revealContents: true),
    );
    if (CollectibleCardLayout.isPngAsset(path)) {
      image = ColoredBox(color: Colors.white, child: image);
    }
    if (fullBleed) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CollectibleCardLayout.artRadius),
      child: image,
    );
  }

  Widget _buildQuoteControls(ColorScheme scheme) {
    final showRandom = _phyEntries.length > 1;
    return Row(
      children: [
        if (showRandom)
          IconButton(
            tooltip: 'Random entry',
            onPressed: () {
              final candidates = _phyEntries
                  .where((e) => e.text != _currentEntry.text)
                  .toList();
              if (candidates.isEmpty) return;
              setState(() {
                _currentEntry = candidates[Random().nextInt(candidates.length)];
                _activeQuotePanel = '';
              });
            },
            icon: const Icon(Icons.casino_outlined),
          ),
        IconButton(
          tooltip: 'Next entry',
          onPressed: _phyEntries.isEmpty
              ? null
              : () {
                  final i = _phyEntries.indexWhere(
                    (e) => e.text == _currentEntry.text,
                  );
                  final next = i < 0 ? 0 : (i + 1) % _phyEntries.length;
                  setState(() {
                    _currentEntry = _phyEntries[next];
                    _activeQuotePanel = '';
                  });
                },
          icon: const Icon(Icons.skip_next_outlined),
        ),
        IconButton(
          tooltip: 'Show all entries',
          onPressed: _phyEntries.isEmpty
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
          tooltip: 'Edit entries',
          onPressed: card.sourceItem == null
              ? null
              : () {
                  setState(() {
                    _activeQuotePanel = _activeQuotePanel == 'edit'
                        ? ''
                        : 'edit';
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
          itemCount: _phyEntries.length,
          separatorBuilder: (_, __) => Divider(
            height: AppUiSizes.md,
            color: scheme.outline.withValues(alpha: 0.32),
          ),
          itemBuilder: (context, index) {
            final entry = _phyEntries[index];
            final linkedCard = _getLinkedCard(entry.linkedCardId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppUiSizes.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1}. ${entry.text}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (linkedCard != null) ...[
                    const SizedBox(width: AppUiSizes.xs),
                    Tooltip(
                      message: linkedCard.title,
                      child: CollectibleCardArt(
                        card: linkedCard,
                        size: 28,
                        revealContents: true,
                      ),
                    ),
                  ],
                ],
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
              hintText: 'One entry per line',
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
              child: const Text('Save entries'),
            ),
          ),
        ],
      ),
    );
  }
}
