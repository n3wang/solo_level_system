// lib/screens/rewards_screen.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

/// Progression is points + cards only (no XP / levels). This screen shows the
/// points wallet + session stats and lets the user manage custom rewards.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProgressModel? userProgress;
  List<RewardModel> rewards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!Hive.isBoxOpen('userProgress')) {
        await Hive.openBox<UserProgressModel>('userProgress');
      }
      final progressBox = Hive.box<UserProgressModel>('userProgress');
      userProgress = progressBox.get('progress');

      if (!Hive.isBoxOpen('rewards')) {
        await Hive.openBox<RewardModel>('rewards');
      }
      final rewardsBox = Hive.box<RewardModel>('rewards');
      rewards = rewardsBox.values.toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading rewards data: $e');
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
        appBar: AppBar(title: const Text('Rewards & Progress')),
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & Progress'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.insights), text: 'Progress'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Rewards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgressTab(),
          _buildRewardsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              heroTag: 'rewards_add_reward',
              onPressed: _showAddRewardDialog,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              tooltip: 'Create Custom Reward',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildProgressTab() {
    if (userProgress == null) {
      return const Center(child: Text('No progress data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPointsOverview(),
          const SizedBox(height: 24),
          _buildStatistics(),
        ],
      ),
    );
  }

  Widget _buildPointsOverview() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.primary,
                  child: const Icon(Icons.stars, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${userProgress!.availablePoints} points',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Earned ${userProgress!.totalPointsEarned} · Spent ${userProgress!.totalPointsSpent}',
                        style: TextStyle(
                          color: AppColorPalette.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Sessions',
                    '${userProgress!.totalPomodoroSessions}',
                    Icons.timer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Current Streak',
                    '${userProgress!.currentStreak} days',
                    Icons.local_fire_department,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title,
              style: TextStyle(
                  color: AppColorPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatRow(
                'Total Sessions', '${userProgress!.totalPomodoroSessions}'),
            _buildStatRow('Sessions Today', '${userProgress!.getSessionsToday()}'),
            _buildStatRow(
                'Sessions This Week', '${userProgress!.getSessionsThisWeek()}'),
            _buildStatRow('Longest Streak', '${userProgress!.longestStreak} days'),
            _buildStatRow('Next Milestone', userProgress!.nextMilestone),
            _buildStatRow('Points Earned', '${userProgress!.totalPointsEarned}'),
            _buildStatRow('Points Spent', '${userProgress!.totalPointsSpent}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    final activeRewards = rewards.where((r) => r.canBePurchased).toList();
    final purchasedRewards = rewards.where((r) => r.wasEverPurchased).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            tabs: [
              Tab(text: 'Available (${activeRewards.length})'),
              Tab(text: 'Purchased (${purchasedRewards.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRewardsList(activeRewards, true),
                _buildRewardsList(purchasedRewards, false),
              ],
            ),
          ),
        ],
      ),
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
              color: AppColorPalette.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              canPurchase
                  ? 'No rewards created yet'
                  : 'No rewards purchased yet',
              style: TextStyle(
                color: AppColorPalette.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canPurchase) ...[
              const SizedBox(height: 8),
              Text(
                'Tap the + button to create your first reward!\nSet your own point costs for treats you want.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColorPalette.textSecondary, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    final groupedRewards = <String, List<RewardModel>>{};
    for (final reward in rewardList) {
      groupedRewards.putIfAbsent(reward.category, () => []).add(reward);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedRewards.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.value.first.categoryDisplay,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...entry.value
                .map((reward) => _buildRewardCard(reward, canPurchase)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRewardCard(RewardModel reward, bool canPurchase) {
    final canAfford =
        (userProgress?.availablePoints ?? 0) >= reward.pointsCost;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _parseColor(reward.color) ?? Theme.of(context).primaryColor,
          child: Icon(_getIconData(reward.iconName), color: Colors.white),
        ),
        title:
            Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward.description),
            if (reward.timesPurchased > 0)
              Text(
                'Purchased ${reward.timesPurchased} time(s)',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w500),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.green : Colors.red,
                    ),
                  ),
                  if (!canAfford)
                    Text(
                      'Need ${reward.pointsCost - (userProgress?.availablePoints ?? 0)} more',
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                    ),
                ],
              )
            : const Icon(Icons.check_circle, color: Colors.green),
        onTap: canPurchase && canAfford ? () => _purchaseReward(reward) : null,
      ),
    );
  }

  void _purchaseReward(RewardModel reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Reward'),
        content: Text(
          'Purchase "${reward.title}" for ${reward.pointsCost} points?\n\nYou will have ${(userProgress?.availablePoints ?? 0) - reward.pointsCost} points remaining.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (userProgress?.spendPoints(reward.pointsCost) ?? false) {
                reward.purchase();
                setState(() {});
                Navigator.of(context).pop();
                showAppSnack(
                  context,
                  text: '🎉 Reward purchased! Enjoy your treat!',
                );
              }
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
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
        title: const Text('Create Your Reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Reward Title',
                  hintText: 'e.g., "New Phone Case"',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this reward for?',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: 'Points Cost',
                  hintText:
                      'You decide! 50 for small treats, 500+ for bigger ones',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
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
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
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
            child: const Text('Create Reward'),
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

    if (!mounted) return;
    showAppSnack(
      context,
      text: '🎉 Your reward has been created!',
    );
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
