import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/utils/card_content_seed_service.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/utils/collectible_deck_seed_service.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';
import 'package:solo_level_system/widgets/common/help_button.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';

class CardsHubScreen extends StatefulWidget {
  const CardsHubScreen({super.key});

  @override
  State<CardsHubScreen> createState() => _CardsHubScreenState();
}

class _CardsHubScreenState extends State<CardsHubScreen> {
  String _typeFilter = kCollectibleTypeFilters.first;
  String _scopeFilter = 'acquired'; // all | acquired
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _ensureReady();
  }

  Future<void> _ensureReady() async {
    try {
      if (!Hive.isBoxOpen('motivationItems')) {
        await Hive.openBox<CardModel>('motivationItems');
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
      await CardContentSeedService.ensureSeeded();
      await CollectibleDeckSeedService.ensureSeeded();
    } catch (e) {
      debugPrint('CardsHub init fallback: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isReady = true);
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
    final motivationBox = Hive.box<CardModel>('motivationItems');
    final rewardsBox = Hive.box<RewardModel>('rewards');
    final progressBox = Hive.box<UserProgressModel>('userProgress');

    return ValueListenableBuilder(
      valueListenable: txBox.listenable(),
      builder: (context, Box<MotivationPointsTransactionModel> _, __) {
        return ValueListenableBuilder(
          valueListenable: motivationBox.listenable(),
          builder: (context, Box<CardModel> itemBox, __) {
            return ValueListenableBuilder(
              valueListenable: rewardsBox.listenable(),
              builder: (context, Box<RewardModel> rewardBox, __) {
                return ValueListenableBuilder(
                  valueListenable: progressBox.listenable(),
                  builder: (context, Box<UserProgressModel> userBox, __) {
                    final userProgress =
                        userBox.get('progress') ?? UserProgressModel();
                    final cards = CardRepository.build(
                      cards: itemBox.values.toList(),
                      rewards: rewardBox.values.toList(),
                    );
                    final visible = cards.where(_isVisible).toList()
                      ..sort((a, b) {
                        final byBookmark =
                            CardRepository.compareBookmarkedFirst(a, b);
                        if (byBookmark != 0) return byBookmark;
                        return a.title.compareTo(b.title);
                      });

                    final hasBookmarked = _hasBookmarkedCards(cards);

                    return Stack(
                      children: [
                        Column(
                          children: [
                            _buildFilters(hasBookmarked: hasBookmarked),
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
                                          padding: const EdgeInsets.fromLTRB(
                                            AppUiSizes.lg,
                                            AppUiSizes.lg,
                                            AppUiSizes.lg,
                                            88,
                                          ),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing:
                                                    AppUiSizes.md,
                                                mainAxisSpacing: AppUiSizes.md,
                                                childAspectRatio:
                                                    CollectibleCardLayout
                                                        .aspectRatio,
                                              ),
                                          itemCount: visible.length,
                                          itemBuilder: (context, index) {
                                            final card = visible[index];
                                            return CollectibleCardTile(
                                              card: card,
                                              availablePoints: userProgress
                                                  .availablePoints,
                                              onTap: () =>
                                                  showCollectibleCardDetail(
                                                    context: context,
                                                    card: card,
                                                    userProgress: userProgress,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        const Positioned(
                          left: AppUiSizes.lg,
                          bottom: AppUiSizes.lg,
                          child: HelpButton(screenKey: 'motivation_hub'),
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

  bool _isVisible(CatalogCard card) {
    if (_typeFilter == kCollectibleBookmarkFilter) {
      if (!card.isBookmarked) return false;
    } else if (card.typeWire != _typeFilter) {
      return false;
    }
    if (_scopeFilter == 'acquired' && !card.isAcquired) return false;
    return true;
  }

  /// Returns true if there are any bookmarked cards matching the current scope.
  bool _hasBookmarkedCards(List<CatalogCard> cards) {
    for (final card in cards) {
      if (!card.isBookmarked) continue;
      if (_scopeFilter == 'acquired' && !card.isAcquired) continue;
      return true;
    }
    return false;
  }

  Widget _buildFilters({required bool hasBookmarked}) {
    // If bookmark filter is selected but no bookmarked cards exist, reset to first type
    if (_typeFilter == kCollectibleBookmarkFilter && !hasBookmarked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _typeFilter = kCollectibleTypeFilters.first);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppUiSizes.lg,
        AppUiSizes.sm,
        AppUiSizes.lg,
        AppUiSizes.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: all/acquired scope filter (right-aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          const SizedBox(height: AppUiSizes.xs),
          // Row 2: type filters (full width)
          SettingsRectChipGroup<String>(
            size: SettingsRectChipSize.compact,
            spacing: AppUiSizes.xs,
            runSpacing: AppUiSizes.xs,
            value: _typeFilter,
            onChanged: (v) => setState(() => _typeFilter = v),
            options: [
              if (hasBookmarked)
                const SettingsRectChipOption(
                  value: kCollectibleBookmarkFilter,
                  label: '',
                  icon: Icons.bookmark,
                ),
              for (final t in kCollectibleTypeFilters)
                SettingsRectChipOption(value: t, label: t),
            ],
          ),
        ],
      ),
    );
  }
}
