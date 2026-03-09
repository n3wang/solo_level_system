import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/motivation_item_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/motivation_points_service.dart';

class MotivationHubScreen extends StatefulWidget {
  const MotivationHubScreen({super.key});

  @override
  State<MotivationHubScreen> createState() => _MotivationHubScreenState();
}

class _MotivationHubScreenState extends State<MotivationHubScreen> {
  String _typeFilter = 'all'; // all | quote | collection | reward
  String _scopeFilter = 'deck'; // deck | acquired

  @override
  Widget build(BuildContext context) {
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
                    final userProgress = userBox.get('progress') ?? UserProgressModel();
                    final summary = MotivationPointsService.summary();
                    final cards = _buildCards(
                      motivationItems: itemBox.values.toList(),
                      rewards: rewardBox.values.toList(),
                    );
                    final visible = cards.where(_isVisible).toList();

                    return Column(
                      children: [
                        _buildSummaryCard(
                          summary: summary,
                          availablePoints: userProgress.availablePoints,
                        ),
                        _buildFilters(),
                        Expanded(
                          child: visible.isEmpty
                              ? Center(
                                  child: Text(
                                    'No cards for this filter yet',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(AppUiSizes.lg),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: AppUiSizes.lg,
                                        mainAxisSpacing: AppUiSizes.lg,
                                        childAspectRatio: 0.78,
                                      ),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    return _buildCardTile(
                                      context: context,
                                      card: visible[index],
                                      userProgress: userProgress,
                                    );
                                  },
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
          description: item.type == 'quote' && (item.quoteText?.isNotEmpty ?? false)
              ? item.quoteText!
              : item.description,
          category: item.category,
          pointsCost: item.pointsCost,
          isAcquired: item.isAcquired,
          imageIndex: item.imageIndex,
          sourceItem: item,
        ),
      );
    }
    for (final reward in rewards) {
      result.add(
        _MotivationCardVm(
          id: reward.id,
          type: 'reward',
          title: reward.title,
          description: reward.description,
          category: reward.category,
          pointsCost: reward.pointsCost,
          isAcquired: reward.timesPurchased > 0,
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

  Widget _buildSummaryCard({
    required MotivationPointsSummary summary,
    required int availablePoints,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppUiSizes.lg,
        AppUiSizes.lg,
        AppUiSizes.lg,
        AppUiSizes.sm,
      ),
      padding: const EdgeInsets.all(AppUiSizes.lg),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: scheme.primary),
          const SizedBox(width: AppUiSizes.sm),
          Expanded(
            child: Text(
              '$availablePoints (+${summary.lastWeekEarned}/-${summary.lastWeekSpent} lw)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
          Text(
            'total +${summary.totalEarned} / -${summary.totalSpent}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final typeOptions = const [
      'all',
      'quote',
      'collection',
      'reward',
    ];
    final scopeOptions = const ['acquired', 'deck'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppUiSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppUiSizes.sm,
              runSpacing: AppUiSizes.sm,
              children: typeOptions.map((option) {
                final selected = _typeFilter == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => setState(() => _typeFilter = option),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: AppUiSizes.sm),
          Wrap(
            spacing: AppUiSizes.sm,
            children: scopeOptions.map((option) {
              final selected = _scopeFilter == option;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => setState(() => _scopeFilter = option),
              );
            }).toList(),
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
    final statusText = card.isAcquired
        ? 'Acquired'
        : canAfford
        ? '${card.pointsCost} pts'
        : 'Need ${card.pointsCost - userProgress.availablePoints}';

    return InkWell(
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      onTap: card.isAcquired ? null : () => _acquireCard(card, userProgress),
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
            Align(
              alignment: Alignment.topRight,
              child: Text(
                card.type,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Icon(
                  card.type == 'quote'
                      ? Icons.format_quote
                      : card.type == 'reward'
                      ? Icons.card_giftcard
                      : Icons.diamond_outlined,
                  size: 42,
                  color: card.isAcquired
                      ? scheme.tertiary
                      : scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Text(
              card.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppUiSizes.xs),
            Text(
              card.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppUiSizes.xs),
            Text(
              statusText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: card.isAcquired
                    ? scheme.tertiary
                    : canAfford
                    ? scheme.primary
                    : scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acquireCard(
    _MotivationCardVm card,
    UserProgressModel userProgress,
  ) async {
    if (card.isAcquired) return;
    if (!userProgress.spendPoints(card.pointsCost)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points')),
      );
      return;
    }

    if (card.sourceItem != null) {
      final item = card.sourceItem!;
      item.isAcquired = true;
      item.acquiredAt = DateTime.now();
      await item.save();
    }
    if (card.sourceReward != null) {
      card.sourceReward!.purchase();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acquired ${card.title}')),
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
    this.imageIndex,
    this.sourceItem,
    this.sourceReward,
  });
}

