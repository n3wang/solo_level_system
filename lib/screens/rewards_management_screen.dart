// lib/screens/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'motivational_cards_screen.dart';

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
          MotivationalCardsScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddRewardDialog,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add),
              label: Text('Create Reward'),
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
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.stars,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userProgress!.availablePoints} Points Available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      'Earn 1 point per minute of focused work',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                'Create your first reward!\nSet your own point costs for treats you want.',
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
            if (entry.value.isNotEmpty) ...[
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
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Reward', style: TextStyle(color: Colors.red)),
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
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(labelText: 'Points Cost'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
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
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            child: Text('Delete', style: TextStyle(color: Colors.white)),
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
