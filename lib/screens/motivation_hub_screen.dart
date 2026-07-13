import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/motivation_item_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:sprite_sheets/sprite_sheets.dart';

class MotivationHubScreen extends StatefulWidget {
  const MotivationHubScreen({super.key});

  @override
  State<MotivationHubScreen> createState() => _MotivationHubScreenState();
}

class _MotivationHubScreenState extends State<MotivationHubScreen> {
  String _typeFilter = 'all'; // all | quote | collection | reward
  String _scopeFilter = 'all'; // all | acquired
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _ensureReady();
  }

  Future<void> _ensureReady() async {
    try {
      if (!Hive.isBoxOpen('motivationItems')) {
        await Hive.openBox<MotivationItemModel>('motivationItems');
      }
      if (!Hive.isBoxOpen('motivationPointsTransactions')) {
        await Hive.openBox<MotivationPointsTransactionModel>(
          'motivationPointsTransactions',
        );
      }
      if (!Hive.isBoxOpen('rewards')) {
        await Hive.openBox<RewardModel>('rewards');
      }
      if (!Hive.isBoxOpen('userProgress')) {
        await Hive.openBox<UserProgressModel>('userProgress');
      }
      await RewardSeedService.ensureDefaultBoardgameRewards();
      await MotivationSeedService.ensureSeeded();
    } catch (e) {
      debugPrint('MotivationHub init fallback: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final txBox = Hive.box<MotivationPointsTransactionModel>(
      'motivationPointsTransactions',
    );
    final motivationBox = Hive.box<MotivationItemModel>('motivationItems');
    final rewardsBox = Hive.box<RewardModel>('rewards');
    final progressBox = Hive.box<UserProgressModel>('userProgress');

    return ValueListenableBuilder(
      valueListenable: txBox.listenable(),
      builder: (context, Box<MotivationPointsTransactionModel> _, __) {
        return ValueListenableBuilder(
          valueListenable: motivationBox.listenable(),
          builder: (context, Box<MotivationItemModel> itemBox, __) {
            return ValueListenableBuilder(
              valueListenable: rewardsBox.listenable(),
              builder: (context, Box<RewardModel> rewardBox, __) {
                return ValueListenableBuilder(
                  valueListenable: progressBox.listenable(),
                  builder: (context, Box<UserProgressModel> userBox, __) {
                    final userProgress =
                        userBox.get('progress') ?? UserProgressModel();
                    final cards = _buildCards(
                      motivationItems: itemBox.values.toList(),
                      rewards: rewardBox.values.toList(),
                    );
                    final visible = cards.where(_isVisible).toList();

                    return Column(
                      children: [
                        _buildFilters(),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: visible.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No cards for this filter yet',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          final width = constraints.maxWidth;
                                          final crossAxisCount = width >= 700
                                              ? 5
                                              : width >= 520
                                              ? 4
                                              : 3;
                                          return GridView.builder(
                                            padding: const EdgeInsets.all(
                                              AppUiSizes.lg,
                                            ),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      crossAxisCount,
                                                  crossAxisSpacing:
                                                      AppUiSizes.md,
                                                  mainAxisSpacing:
                                                      AppUiSizes.md,
                                                  childAspectRatio: 0.84,
                                                ),
                                            itemCount: visible.length,
                                            itemBuilder: (context, index) {
                                              return _buildCardTile(
                                                context: context,
                                                card: visible[index],
                                                userProgress: userProgress,
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppUiSizes.lg,
                                  AppUiSizes.xs,
                                  AppUiSizes.lg,
                                  AppUiSizes.lg,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showQuickCreateDialog(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<_MotivationCardVm> _buildCards({
    required List<MotivationItemModel> motivationItems,
    required List<RewardModel> rewards,
  }) {
    final result = <_MotivationCardVm>[];
    for (final item in motivationItems) {
      result.add(
        _MotivationCardVm(
          id: item.id,
          type: item.type,
          title: item.title,
          description: item.description,
          category: item.category,
          pointsCost: item.pointsCost,
          isAcquired: item.hasAnyAcquisition,
          acquisitionCount: item.acquisitionCount,
          imageIndex: item.imageIndex,
          sourceItem: item,
        ),
      );
    }
    for (final reward in rewards) {
      final isCollectibleSeed =
          reward.metadata['isCollectible'] == true ||
          reward.metadata['source'] == 'default_boardgame_csv' ||
          reward.tags.contains('collectible');
      if (isCollectibleSeed) {
        // Keep collectible boardgame/plant content in collection cards only.
        continue;
      }
      final metadata = reward.metadata;
      final boardgameNumber = metadata['boardgameNumber'];
      final imageIndex = boardgameNumber is num
          ? boardgameNumber.toInt()
          : null;
      result.add(
        _MotivationCardVm(
          id: reward.id,
          type: 'reward',
          title: reward.title,
          description: reward.description,
          category: reward.category,
          pointsCost: reward.pointsCost,
          isAcquired: reward.timesPurchased > 0,
          acquisitionCount: reward.timesPurchased,
          imageIndex: imageIndex,
          sourceReward: reward,
        ),
      );
    }
    return result;
  }

  bool _isVisible(_MotivationCardVm card) {
    if (_typeFilter != 'all' && card.type != _typeFilter) return false;
    if (_scopeFilter == 'acquired' && !card.isAcquired) return false;
    return true;
  }

  List<String> _quoteOptionsForItem(MotivationItemModel item) {
    final quotes = <String>[];
    final metadataQuotes = item.metadata['quotes'];
    if (metadataQuotes is List) {
      for (final entry in metadataQuotes) {
        final text = entry?.toString().trim() ?? '';
        if (text.isNotEmpty) quotes.add(text);
      }
    }
    final quoteText = item.quoteText?.trim() ?? '';
    if (quoteText.isNotEmpty) {
      quotes.addAll(
        quoteText.split(';').map((q) => q.trim()).where((q) => q.isNotEmpty),
      );
    }
    return quotes.toSet().toList();
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppUiSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SettingsRectChipGroup<String>(
              size: SettingsRectChipSize.compact,
              spacing: AppUiSizes.xs,
              runSpacing: AppUiSizes.xs,
              value: _typeFilter,
              onChanged: (v) => setState(() => _typeFilter = v),
              options: const [
                SettingsRectChipOption(value: 'all', label: 'all'),
                SettingsRectChipOption(value: 'quote', label: 'quote'),
                SettingsRectChipOption(
                  value: 'collection',
                  label: 'collection',
                ),
                SettingsRectChipOption(value: 'reward', label: 'reward'),
              ],
            ),
          ),
          const SizedBox(width: AppUiSizes.xs),
          SettingsRectChipGroup<String>(
            size: SettingsRectChipSize.compact,
            spacing: AppUiSizes.xs,
            value: _scopeFilter,
            onChanged: (v) => setState(() => _scopeFilter = v),
            options: const [
              SettingsRectChipOption(value: 'all', label: 'all'),
              SettingsRectChipOption(value: 'acquired', label: 'acquired'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile({
    required BuildContext context,
    required _MotivationCardVm card,
    required UserProgressModel userProgress,
  }) {
    final canAfford = userProgress.availablePoints >= card.pointsCost;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      onTap: () => _showCardDetailsModal(
        context: context,
        card: card,
        userProgress: userProgress,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppUiSizes.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
          border: Border.all(
            color: card.isAcquired
                ? scheme.tertiary
                : scheme.outline.withValues(alpha: 0.6),
          ),
          color: card.isAcquired
              ? scheme.tertiary.withValues(alpha: 0.08)
              : scheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const SizedBox(width: AppUiSizes.xs),
                Expanded(
                  child: Text(
                    card.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _buildCardArt(card: card, scheme: scheme, size: 52),
              ),
            ),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppUiSizes.xs),
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
                      ? scheme.tertiary
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

  Widget _buildCardArt({
    required _MotivationCardVm card,
    required ColorScheme scheme,
    double size = 56,
  }) {
    final index = card.imageIndex;
    if (index != null && index > 0) {
      return SpriteImage(sheet: 'motivation_64', index: index - 1, size: size);
    }

    return Icon(
      card.type == 'quote'
          ? Icons.format_quote
          : card.type == 'reward'
          ? Icons.card_giftcard
          : Icons.diamond_outlined,
      size: size * 0.75,
      color: card.isAcquired
          ? scheme.tertiary
          : scheme.onSurface.withValues(alpha: 0.5),
    );
  }

  Future<bool> _acquireCard(
    _MotivationCardVm card,
    UserProgressModel userProgress,
  ) async {
    if (card.sourceReward != null && !card.sourceReward!.canBePurchased) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This reward is no longer available')),
      );
      return false;
    }

    final hasExistingAcquisition = card.sourceItem != null
        ? card.sourceItem!.hasAnyAcquisition
        : card.sourceReward != null && card.sourceReward!.timesPurchased > 0;
    if (hasExistingAcquisition) {
      final shouldRepeat = await _confirmRepeatAcquisition(card);
      if (!shouldRepeat) return false;
    }

    if (!userProgress.spendPoints(card.pointsCost)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough points')));
      return false;
    }

    if (card.sourceItem != null) {
      final item = card.sourceItem!;
      item.recordAcquisition();
      await item.save();
    }
    if (card.sourceReward != null) {
      card.sourceReward!.purchase();
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card.sourceItem != null
              ? 'Acquired ${card.title} (${card.sourceItem!.acquisitionCount}x)'
              : 'Acquired ${card.title}',
        ),
      ),
    );
    return true;
  }

  Future<bool> _confirmRepeatAcquisition(_MotivationCardVm card) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Acquire again?'),
          content: Text(
            'You already acquired "${card.title}". Do you want to acquire it again for ${card.pointsCost} points?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Acquire again'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showCardDetailsModal({
    required BuildContext context,
    required _MotivationCardVm card,
    required UserProgressModel userProgress,
  }) async {
    final canAfford = userProgress.availablePoints >= card.pointsCost;
    final canPurchaseReward = card.sourceReward == null
        ? true
        : card.sourceReward!.canBePurchased;
    final canAttemptAcquire = canAfford && canPurchaseReward;
    final scheme = Theme.of(context).colorScheme;
    List<String> quoteOptions =
        (card.type == 'quote' && card.sourceItem != null)
        ? _quoteOptionsForItem(card.sourceItem!)
        : const <String>[];
    final quoteEditorController = TextEditingController(
      text: quoteOptions.join('\n'),
    );
    final descriptionEditorController = TextEditingController(
      text: card.sourceItem?.description ?? card.description,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        var currentQuote = quoteOptions.isNotEmpty
            ? quoteOptions.first
            : card.description;
        var currentDescription =
            card.sourceItem?.description ?? card.description;
        String activeQuotePanel = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isQuoteCard = card.type == 'quote';
            final showRandom = quoteOptions.length > 1;
            final screenHeight = MediaQuery.of(context).size.height;
            final modalHeight = screenHeight * 0.66;
            return AlertDialog(
              contentPadding: const EdgeInsets.all(AppUiSizes.lg),
              content: SizedBox(
                width: 340,
                height: modalHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          card.type,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppUiSizes.sm),
                    Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        scale: 1.0,
                        child: _buildCardArt(
                          card: card,
                          scheme: scheme,
                          size: 116,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppUiSizes.md),
                    Text(
                      'Category: ${card.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppUiSizes.xs),
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
                    if (isQuoteCard &&
                        currentDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: AppUiSizes.sm),
                      Text(
                        currentDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppUiSizes.sm),
                    if (isQuoteCard) ...[
                      Row(
                        children: [
                          if (showRandom)
                            IconButton(
                              tooltip: 'Random quote',
                              onPressed: () {
                                final candidates = quoteOptions
                                    .where((quote) => quote != currentQuote)
                                    .toList();
                                if (candidates.isEmpty) return;
                                final random = Random();
                                setDialogState(() {
                                  currentQuote =
                                      candidates[random.nextInt(
                                        candidates.length,
                                      )];
                                  activeQuotePanel = '';
                                });
                              },
                              icon: const Icon(Icons.casino_outlined),
                            ),
                          IconButton(
                            tooltip: 'Next quote',
                            onPressed: quoteOptions.isEmpty
                                ? null
                                : () {
                                    final currentIndex = quoteOptions.indexOf(
                                      currentQuote,
                                    );
                                    final nextIndex = currentIndex < 0
                                        ? 0
                                        : (currentIndex + 1) %
                                              quoteOptions.length;
                                    setDialogState(() {
                                      currentQuote = quoteOptions[nextIndex];
                                      activeQuotePanel = '';
                                    });
                                  },
                            icon: const Icon(Icons.skip_next_outlined),
                          ),
                          IconButton(
                            tooltip: 'Show all quotes',
                            onPressed: quoteOptions.isEmpty
                                ? null
                                : () {
                                    setDialogState(() {
                                      activeQuotePanel =
                                          activeQuotePanel == 'show_all'
                                          ? ''
                                          : 'show_all';
                                    });
                                  },
                            icon: Icon(
                              Icons.view_list_outlined,
                              color: activeQuotePanel == 'show_all'
                                  ? scheme.primary
                                  : null,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit quotes',
                            onPressed: card.sourceItem == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      activeQuotePanel =
                                          activeQuotePanel == 'edit'
                                          ? ''
                                          : 'edit';
                                    });
                                  },
                            icon: Icon(
                              Icons.edit_outlined,
                              color: activeQuotePanel == 'edit'
                                  ? scheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (activeQuotePanel == 'show_all') ...[
                        const SizedBox(height: AppUiSizes.xs),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.45),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppUiSizes.radiusMd,
                              ),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppUiSizes.sm,
                                vertical: AppUiSizes.xs,
                              ),
                              itemCount: quoteOptions.length,
                              separatorBuilder: (_, __) => Divider(
                                height: AppUiSizes.md,
                                thickness: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.32),
                              ),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppUiSizes.xs,
                                  ),
                                  child: Text(
                                    '${index + 1}. ${quoteOptions[index]}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      if (activeQuotePanel == 'edit') ...[
                        const SizedBox(height: AppUiSizes.xs),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  controller: quoteEditorController,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    hintText: 'One quote per line',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: AppUiSizes.xs),
                                TextField(
                                  controller: descriptionEditorController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Description',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: AppUiSizes.xs),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: card.sourceItem == null
                                        ? null
                                        : () async {
                                            final lines = quoteEditorController
                                                .text
                                                .split('\n')
                                                .map((line) => line.trim())
                                                .where(
                                                  (line) => line.isNotEmpty,
                                                )
                                                .toList();
                                            if (lines.isEmpty) return;
                                            final editedDescription =
                                                descriptionEditorController.text
                                                    .trim();
                                            await _saveQuoteContent(
                                              item: card.sourceItem!,
                                              lines: lines,
                                              description: editedDescription,
                                            );
                                            setDialogState(() {
                                              quoteOptions = lines;
                                              currentQuote = lines.first;
                                              if (editedDescription
                                                  .isNotEmpty) {
                                                currentDescription =
                                                    editedDescription;
                                              }
                                              quoteEditorController.text = lines
                                                  .join('\n');
                                            });
                                          },
                                    child: const Text('Save quotes'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppUiSizes.sm),
                    if (!isQuoteCard || activeQuotePanel.isEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            isQuoteCard ? currentQuote : currentDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppUiSizes.lg),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: !canAttemptAcquire
                              ? null
                              : () async {
                                  final ok = await _acquireCard(
                                    card,
                                    userProgress,
                                  );
                                  if (!mounted || !ok) return;
                                  Navigator.of(context).pop();
                                },
                          child: Text(
                            !canAfford
                                ? 'Not enough'
                                : !canPurchaseReward
                                ? 'Unavailable'
                                : card.isAcquired
                                ? 'Acquire again'
                                : (card.type == 'reward' ? 'Buy' : 'Acquire'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveQuoteContent({
    required MotivationItemModel item,
    required List<String> lines,
    required String description,
  }) async {
    final metadata = Map<String, dynamic>.from(item.metadata);
    metadata['quotes'] = lines;
    item.metadata = metadata;
    item.quoteText = lines.first;
    if (description.isNotEmpty) {
      item.description = description;
    }
    await item.save();
  }

  void _showQuickCreateDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController(
      text: AppEnvironment.quickCreateDefaultCost.toString(),
    );
    var selectedType = 'collection';
    var rewardCategory = 'general';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Quick Create Motivation'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'collection',
                          label: Text('Collection'),
                        ),
                        ButtonSegment(value: 'quote', label: Text('Quote')),
                        ButtonSegment(value: 'reward', label: Text('Reward')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (value) {
                        if (value.isEmpty) return;
                        setDialogState(() {
                          selectedType = value.first;
                        });
                      },
                    ),
                    const SizedBox(height: AppUiSizes.lg),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: selectedType == 'quote'
                            ? 'Person or Topic'
                            : 'Title',
                      ),
                    ),
                    const SizedBox(height: AppUiSizes.lg),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: selectedType == 'quote'
                            ? 'Quote text or context'
                            : 'Description',
                      ),
                    ),
                    const SizedBox(height: AppUiSizes.lg),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points cost',
                      ),
                    ),
                    if (selectedType == 'reward') ...[
                      const SizedBox(height: AppUiSizes.lg),
                      DropdownButtonFormField<String>(
                        initialValue: rewardCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items:
                            const [
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
                                ]
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            rewardCategory = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final points =
                        int.tryParse(pointsController.text.trim()) ?? 0;
                    if (title.isEmpty || points <= 0) return;

                    if (selectedType == 'reward') {
                      final reward = RewardTemplates.createCustomReward(
                        title: title,
                        description: description.isEmpty
                            ? 'Custom reward'
                            : description,
                        pointsCost: points,
                        category: rewardCategory,
                      );
                      await Hive.box<RewardModel>('rewards').add(reward);
                    } else {
                      final item = MotivationItemModel(
                        id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
                        type: selectedType,
                        title: title,
                        description: description.isEmpty
                            ? 'User created $selectedType card'
                            : description,
                        category: selectedType,
                        pointsCost: points,
                        createdAt: DateTime.now(),
                        isSystem: false,
                        quotePerson: selectedType == 'quote' ? title : null,
                        quoteText: selectedType == 'quote'
                            ? (description.isEmpty ? title : description)
                            : null,
                      );
                      await Hive.box<MotivationItemModel>(
                        'motivationItems',
                      ).add(item);
                    }

                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$selectedType card created')),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MotivationCardVm {
  final String id;
  final String type;
  final String title;
  final String description;
  final String category;
  final int pointsCost;
  final bool isAcquired;
  final int acquisitionCount;
  final int? imageIndex;
  final MotivationItemModel? sourceItem;
  final RewardModel? sourceReward;

  const _MotivationCardVm({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.pointsCost,
    required this.isAcquired,
    this.acquisitionCount = 0,
    this.imageIndex,
    this.sourceItem,
    this.sourceReward,
  });
}
