// lib/screens/rewards_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/reward_model.dart';

class RewardsScreen extends StatefulWidget {
  @override
  _RewardsScreenState createState() => _RewardsScreenState();
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
    _tabController = TabController(length: 3, vsync: this);
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
        appBar: AppBar(title: Text('Rewards & Progress')),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Rewards & Progress'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.star), text: 'Progress'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Rewards'),
            Tab(icon: Icon(Icons.lock_open), text: 'Features'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgressTab(),
          _buildRewardsTab(),
          _buildFeaturesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showAddRewardDialog,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              child: Icon(Icons.add),
              tooltip: 'Create Custom Reward',
            )
          : null,
    );
  }

  Widget _buildProgressTab() {
    if (userProgress == null) {
      return Center(child: Text('No progress data available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProgressOverview(),
          SizedBox(height: 24),
          _buildRewardSystemInfo(),
          SizedBox(height: 24),
          _buildLevelProgress(),
          SizedBox(height: 24),
          _buildStatistics(),
          SizedBox(height: 24),
          _buildMilestones(),
        ],
      ),
    );
  }

  Widget _buildProgressOverview() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    '${userProgress!.currentLevel}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProgress!.levelTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${userProgress!.totalExperience} XP • ${userProgress!.availablePoints} Points',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Sessions',
                    '${userProgress!.totalPomodoroSessions}',
                    Icons.timer,
                  ),
                ),
                SizedBox(width: 16),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRewardSystemInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'How Rewards Work',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.timer,
              'Minutes = Rewards',
              'Earn 1 XP and 1 Point per minute spent on pomodoro sessions',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.local_fire_department,
              'Streak Bonus',
              'Every 5-day streak adds +5 bonus XP per session',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.trending_up,
              'Level Bonus',
              'Higher levels provide small XP bonuses',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.add_circle_outline,
              'Create Your Rewards',
              'Design custom rewards with your own point costs using the + button',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelProgress() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Level ${userProgress!.currentLevel}'),
                Text('Level ${userProgress!.currentLevel + 1}'),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: userProgress!.progressToNextLevel,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${userProgress!.experienceNeededForNextLevel} XP needed for next level',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatRow(
              'Total Sessions',
              '${userProgress!.totalPomodoroSessions}',
            ),
            _buildStatRow(
              'Sessions Today',
              '${userProgress!.getSessionsToday()}',
            ),
            _buildStatRow(
              'Sessions This Week',
              '${userProgress!.getSessionsThisWeek()}',
            ),
            _buildStatRow(
              'Longest Streak',
              '${userProgress!.longestStreak} days',
            ),
            _buildStatRow(
              'Points Earned',
              '${userProgress!.totalPointsEarned}',
            ),
            _buildStatRow('Points Spent', '${userProgress!.totalPointsSpent}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMilestones() {
    final milestones = ProgressConstants.MILESTONES;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...milestones.map((milestone) {
              final isCompleted =
                  userProgress!.totalPomodoroSessions >= milestone['sessions'];
              return ListTile(
                leading: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.green : Colors.grey,
                ),
                title: Text(milestone['title']),
                subtitle: Text('${milestone['sessions']} sessions'),
                trailing: Text(
                  '+${milestone['points_bonus']} pts',
                  style: TextStyle(
                    color: isCompleted ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
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
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              canPurchase
                  ? 'No rewards created yet'
                  : 'No rewards purchased yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canPurchase) ...[
              SizedBox(height: 8),
              Text(
                'Tap the + button to create your first reward!\nSet your own point costs for treats you want.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
      padding: EdgeInsets.all(16),
      children: groupedRewards.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.value.first.categoryDisplay,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...entry.value.map(
              (reward) => _buildRewardCard(reward, canPurchase),
            ),
            SizedBox(height: 16),
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
              _parseColor(reward.color) ?? Theme.of(context).primaryColor,
          child: Icon(_getIconData(reward.iconName), color: Colors.white),
        ),
        title: Text(
          reward.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward.description),
            if (reward.timesPurchased > 0)
              Text(
                'Purchased ${reward.timesPurchased} time(s)',
                style: TextStyle(
                  color: Colors.green,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.green : Colors.red,
                    ),
                  ),
                  if (!canAfford)
                    Text(
                      'Need ${reward.pointsCost - userProgress!.availablePoints} more',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                    ),
                ],
              )
            : Icon(Icons.check_circle, color: Colors.green),
        onTap: canPurchase && canAfford ? () => _purchaseReward(reward) : null,
      ),
    );
  }

  Widget _buildFeaturesTab() {
    final featureRequirements = ProgressConstants.FEATURE_UNLOCK_REQUIREMENTS;
    final featureDescriptions = ProgressConstants.FEATURE_DESCRIPTIONS;

    return ListView(
      padding: EdgeInsets.all(16),
      children: featureRequirements.entries.map((entry) {
        final isUnlocked =
            userProgress!.canUnlockFeature(entry.key, entry.value) ||
            userProgress!.isFeatureUnlocked(entry.key);
        final canUnlock = userProgress!.canUnlockFeature(
          entry.key,
          entry.value,
        );

        return Card(
          child: ListTile(
            leading: Icon(
              isUnlocked ? Icons.lock_open : Icons.lock,
              color: isUnlocked ? Colors.green : Colors.grey,
            ),
            title: Text(
              entry.key.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(featureDescriptions[entry.key] ?? 'Feature description'),
                SizedBox(height: 4),
                Text(
                  'Requires ${entry.value} XP',
                  style: TextStyle(
                    color: isUnlocked ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: isUnlocked
                ? Icon(Icons.check_circle, color: Colors.green)
                : canUnlock
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _unlockFeature(entry.key),
                    child: Text('Unlock'),
                  )
                : Text(
                    '${entry.value - userProgress!.totalExperience} XP needed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
          ),
        );
      }).toList(),
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
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (userProgress!.spendPoints(reward.pointsCost)) {
                reward.purchase();
                setState(() {});
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Reward purchased! Enjoy your treat!'),
                    backgroundColor: Colors.green,
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

  void _unlockFeature(String featureId) {
    userProgress!.unlockFeature(featureId);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Feature unlocked! Check the app for new options.'),
        backgroundColor: Colors.green,
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
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this reward for?',
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  labelText: 'Points Cost',
                  hintText:
                      'You decide! 50 for small treats, 500+ for bigger ones',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
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
