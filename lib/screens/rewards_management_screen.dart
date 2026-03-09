// lib/screens/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/motivation_item_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/screens/motivation_hub_screen.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/reward_seed_service.dart';

class RewardsManagementScreen extends StatefulWidget {
  const RewardsManagementScreen({super.key});

  @override
  _RewardsManagementScreenState createState() =>
      _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends State<RewardsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProgressModel? userProgress;
  List<RewardModel> rewards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user progress
      if (!Hive.isBoxOpen('userProgress')) {
        await Hive.openBox<UserProgressModel>('userProgress');
      }
      final progressBox = Hive.box<UserProgressModel>('userProgress');
      userProgress = progressBox.get('progress');

      // Load rewards
      if (!Hive.isBoxOpen('rewards')) {
        await Hive.openBox<RewardModel>('rewards');
      }
      if (!Hive.isBoxOpen('motivationItems')) {
        await Hive.openBox<MotivationItemModel>('motivationItems');
      }
      await RewardSeedService.ensureDefaultBoardgameRewards();
      await MotivationSeedService.ensureSeeded();
      final rewardsBox = Hive.box<RewardModel>('rewards');
      rewards = rewardsBox.values.toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading rewards data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Rewards')),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.card_giftcard), text: 'My Rewards'),
            Tab(icon: Icon(Icons.history), text: 'Purchased'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Motivation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableRewardsTab(),
          _buildPurchasedRewardsTab(),
          const MotivationHubScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddRewardDialog,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Create Reward'),
            )
          : _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: _showQuickCreateMotivationDialog,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
    );
  }

  Widget _buildAvailableRewardsTab() {
    if (userProgress == null) {
      return Center(child: Text('No progress data available'));
    }

    return Column(
      children: [
        // Points overview card
        Container(
          margin: const EdgeInsets.all(AppUiSizes.lg),
          padding: const EdgeInsets.all(AppUiSizes.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.stars,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppUiSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userProgress!.availablePoints} Points Available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Earn 1 point per minute of focused work',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: AppColorPalette.fontSizeBody,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Rewards list
        Expanded(
          child: _buildRewardsList(
            rewards.where((r) => r.canBePurchased).toList(),
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchasedRewardsTab() {
    return _buildRewardsList(
      rewards.where((r) => r.wasEverPurchased).toList(),
      false,
    );
  }

  Widget _buildRewardsList(List<RewardModel> rewardList, bool canPurchase) {
    if (rewardList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canPurchase ? Icons.add_circle_outline : Icons.history,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppUiSizes.lg),
            Text(
              canPurchase
                  ? 'No rewards created yet'
                  : 'No rewards purchased yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canPurchase) ...[
              const SizedBox(height: AppUiSizes.sm),
              Text(
                'Create your first reward!\nSet your own point costs for treats you want.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: AppColorPalette.fontSizeBody,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group rewards by category
    final groupedRewards = <String, List<RewardModel>>{};
    for (final reward in rewardList) {
      groupedRewards.putIfAbsent(reward.category, () => []).add(reward);
    }

    return ListView(
      padding: const EdgeInsets.all(AppUiSizes.lg),
      children: groupedRewards.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.value.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppUiSizes.sm),
                child: Text(
                  entry.value.first.categoryDisplay,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: AppColorPalette.fontSizeSubtitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...entry.value.map(
                (reward) => _buildRewardCard(reward, canPurchase),
              ),
              const SizedBox(height: AppUiSizes.lg),
            ],
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRewardCard(RewardModel reward, bool canPurchase) {
    final canAfford = userProgress!.availablePoints >= reward.pointsCost;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _parseColor(reward.color) ??
              Theme.of(context).colorScheme.primary,
          child: Icon(
            _getIconData(reward.iconName),
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        title: Text(
          reward.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward.description),
            if (reward.timesPurchased > 0)
              Text(
                'Purchased ${reward.timesPurchased} time(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: canPurchase
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${reward.pointsCost} pts',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: canAfford
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (!canAfford)
                    Text(
                      'Need ${reward.pointsCost - userProgress!.availablePoints} more',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: AppColorPalette.fontSizeXSmall,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              )
            : Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.tertiary,
              ),
        onTap: canPurchase && canAfford ? () => _purchaseReward(reward) : null,
        onLongPress: canPurchase ? () => _showRewardOptions(reward) : null,
      ),
    );
  }

  void _showRewardOptions(RewardModel reward) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Reward'),
            onTap: () {
              Navigator.pop(context);
              _editReward(reward);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete Reward',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteReward(reward);
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _editReward(RewardModel reward) {
    final titleController = TextEditingController(text: reward.title);
    final descriptionController = TextEditingController(
      text: reward.description,
    );
    final pointsController = TextEditingController(
      text: reward.pointsCost.toString(),
    );
    String selectedCategory = reward.category;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Reward Title'),
              ),
              const SizedBox(height: AppUiSizes.lg),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: AppUiSizes.lg),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(labelText: 'Points Cost'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppUiSizes.lg),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items:
                    [
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
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  pointsController.text.isNotEmpty) {
                final points = int.tryParse(pointsController.text);
                if (points != null && points > 0) {
                  reward.title = titleController.text;
                  reward.description = descriptionController.text;
                  reward.pointsCost = points;
                  reward.category = selectedCategory;
                  reward.save();
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Reward updated!')));
                }
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteReward(RewardModel reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reward'),
        content: Text(
          'Are you sure you want to delete "${reward.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              reward.delete();
              setState(() {
                rewards.remove(reward);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Reward deleted')));
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }

  void _purchaseReward(RewardModel reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase Reward'),
        content: Text(
          'Purchase "${reward.title}" for ${reward.pointsCost} points?\n\nYou will have ${userProgress!.availablePoints - reward.pointsCost} points remaining.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              if (userProgress!.spendPoints(reward.pointsCost)) {
                reward.purchase();
                setState(() {});
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Reward purchased! Enjoy your treat!'),
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                );
              }
            },
            child: Text('Purchase'),
          ),
        ],
      ),
    );
  }

  void _showQuickCreateMotivationDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController(text: '20');
    var selectedType = 'collection'; // collection | quote | reward
    String selectedCategory = 'general';

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
                            ? 'Person / Topic'
                            : 'Title',
                      ),
                    ),
                    const SizedBox(height: AppUiSizes.lg),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: selectedType == 'quote'
                            ? 'Description or quote context'
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
                        initialValue: selectedCategory,
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
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCategory = value;
                            });
                          }
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
                      await _addCustomReward(
                        title,
                        description,
                        points,
                        selectedCategory,
                      );
                    } else {
                      final box = Hive.box<MotivationItemModel>(
                        'motivationItems',
                      );
                      await box.add(
                        MotivationItemModel(
                          id: 'quick_${selectedType}_${DateTime.now().millisecondsSinceEpoch}',
                          type: selectedType,
                          title: title,
                          description: description.isEmpty
                              ? 'User-created $selectedType card'
                              : description,
                          category: selectedType,
                          pointsCost: points,
                          createdAt: DateTime.now(),
                          isSystem: false,
                          quotePerson: selectedType == 'quote' ? title : null,
                          quoteText: selectedType == 'quote'
                              ? (description.isEmpty ? title : description)
                              : null,
                        ),
                      );
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

  void _showAddRewardDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController();
    String selectedCategory = 'general';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Your Reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Reward Title',
                  hintText: 'e.g., "New Phone Case"',
                ),
              ),
              const SizedBox(height: AppUiSizes.lg),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this reward for?',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppUiSizes.lg),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  labelText: 'Points Cost',
                  hintText:
                      'You decide! 50 for small treats, 500+ for bigger ones',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppUiSizes.lg),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items:
                    [
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
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) selectedCategory = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  pointsController.text.isNotEmpty) {
                final points = int.tryParse(pointsController.text);
                if (points != null && points > 0) {
                  _addCustomReward(
                    titleController.text,
                    descriptionController.text,
                    points,
                    selectedCategory,
                  );
                  Navigator.of(context).pop();
                }
              }
            },
            child: Text('Create Reward'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomReward(
    String title,
    String description,
    int points,
    String category,
  ) async {
    final reward = RewardTemplates.createCustomReward(
      title: title,
      description: description,
      pointsCost: points,
      category: category,
    );

    final box = Hive.box<RewardModel>('rewards');
    await box.add(reward);

    setState(() {
      rewards.add(reward);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('🎉 Your reward has been created!')));
  }

  Color? _parseColor(String? colorHex) {
    if (colorHex == null) return null;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'precision_manufacturing':
        return Icons.precision_manufacturing;
      case 'laptop':
        return Icons.laptop;
      case 'headphones':
        return Icons.headphones;
      case 'movie':
        return Icons.movie;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'cake':
        return Icons.cake;
      case 'spa':
        return Icons.spa;
      case 'palette':
        return Icons.palette;
      case 'book':
        return Icons.book;
      case 'school':
        return Icons.school;
      case 'schedule':
        return Icons.schedule;
      case 'smartphone':
        return Icons.smartphone;
      default:
        return Icons.card_giftcard;
    }
  }
}
