// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_settings_model.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserSettingsModel userSettings = UserSettingsModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      Box<UserSettingsModel> userBox;

      // Check if box is already open, if not open it
      if (!Hive.isBoxOpen('userSettings')) {
        userBox = await Hive.openBox<UserSettingsModel>('userSettings');
      } else {
        userBox = Hive.box<UserSettingsModel>('userSettings');
      }

      // Get existing settings or create defaults
      userSettings = userBox.get('settings') ?? UserSettingsModel();

      // Save defaults if they don't exist
      if (userBox.get('settings') == null) {
        await userBox.put('settings', userSettings);
      }
    } catch (e) {
      print('Error loading settings: $e');
      userSettings = UserSettingsModel(); // Use defaults
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserSettings() async {
    try {
      Box<UserSettingsModel> box;

      // Check if box is already open, if not open it
      if (!Hive.isBoxOpen('userSettings')) {
        box = await Hive.openBox<UserSettingsModel>('userSettings');
      } else {
        box = Hive.box<UserSettingsModel>('userSettings');
      }

      await box.put('settings', userSettings);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.palette), text: 'Appearance'),
            Tab(icon: Icon(Icons.timer), text: 'Sessions'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppearanceTab(),
                _buildSessionsTab(),
                _buildNotificationsTab(),
              ],
            ),
    );
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Theme'),
        ListTile(
          title: Text('Theme Mode'),
          subtitle: Text('Choose your preferred theme'),
          trailing: DropdownButton<String>(
            key: Key('theme_dropdown'),
            value: userSettings.theme,
            items: [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (value) async {
              setState(() {
                userSettings.theme = value!;
              });
              await _saveUserSettings();
            },
          ),
        ),
        ListTile(
          title: Text('Primary Color'),
          subtitle: Text('Choose your accent color'),
          trailing: DropdownButton<String>(
            key: Key('color_dropdown'),
            value: userSettings.primaryColor,
            items: [
              DropdownMenuItem(value: 'red', child: Text('Red')),
              DropdownMenuItem(value: 'blue', child: Text('Blue')),
              DropdownMenuItem(value: 'green', child: Text('Green')),
              DropdownMenuItem(value: 'purple', child: Text('Purple')),
              DropdownMenuItem(value: 'orange', child: Text('Orange')),
            ],
            onChanged: (value) async {
              setState(() {
                userSettings.primaryColor = value!;
              });
              await _saveUserSettings();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Default Durations'),
        ListTile(
          title: Text('Work Duration'),
          subtitle: Text('${userSettings.defaultWorkMinutes} minutes'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: userSettings.defaultWorkMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (value) async {
                setState(() {
                  userSettings.defaultWorkMinutes = value.round();
                });
                await _saveUserSettings();
              },
            ),
          ),
        ),
        ListTile(
          title: Text('Break Duration'),
          subtitle: Text('${userSettings.defaultBreakMinutes} minutes'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: userSettings.defaultBreakMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (value) async {
                setState(() {
                  userSettings.defaultBreakMinutes = value.round();
                });
                await _saveUserSettings();
              },
            ),
          ),
        ),
        Divider(),
        _buildSectionHeader('Automation'),
        SwitchListTile(
          title: Text('Auto-start Breaks'),
          subtitle: Text('Automatically start break timer after work session'),
          value: userSettings.autoStartBreaks,
          onChanged: (value) async {
            setState(() {
              userSettings.autoStartBreaks = value;
            });
            await _saveUserSettings();
          },
        ),
        SwitchListTile(
          title: Text('Auto-start Work'),
          subtitle: Text('Automatically start work timer after break'),
          value: userSettings.autoStartWork,
          onChanged: (value) async {
            setState(() {
              userSettings.autoStartWork = value;
            });
            await _saveUserSettings();
          },
        ),
      ],
    );
  }


  Widget _buildNotificationsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Notifications'),
        SwitchListTile(
          title: Text('Enable Notifications'),
          subtitle: Text('Receive session completion notifications'),
          value: userSettings.enableNotifications,
          onChanged: (value) async {
            setState(() {
              userSettings.enableNotifications = value;
            });
            await _saveUserSettings();
          },
        ),
        SwitchListTile(
          title: Text('Enable Sounds'),
          subtitle: Text('Play notification sounds'),
          value: userSettings.enableSounds,
          onChanged: (value) async {
            setState(() {
              userSettings.enableSounds = value;
            });
            await _saveUserSettings();
          },
        ),
        ListTile(
          title: Text('Notification Sound'),
          subtitle: Text(userSettings.notificationSound),
          trailing: DropdownButton<String>(
            value: userSettings.notificationSound,
            items: [
              DropdownMenuItem(value: 'default', child: Text('Default')),
              DropdownMenuItem(value: 'bell', child: Text('Bell')),
              DropdownMenuItem(value: 'chime', child: Text('Chime')),
              DropdownMenuItem(
                value: 'notification',
                child: Text('Notification'),
              ),
            ],
            onChanged: (value) async {
              setState(() {
                userSettings.notificationSound = value!;
              });
              await _saveUserSettings();
            },
          ),
        ),
        Divider(),
        _buildSectionHeader('Privacy'),
        SwitchListTile(
          title: Text('Enable Analytics'),
          subtitle: Text('Help improve the app by sharing usage data'),
          value: userSettings.enableAnalytics,
          onChanged: (value) async {
            setState(() {
              userSettings.enableAnalytics = value;
            });
            await _saveUserSettings();
          },
        ),
        SwitchListTile(
          title: Text('Auto Backup'),
          subtitle: Text('Automatically backup your data'),
          value: userSettings.autoBackup,
          onChanged: (value) async {
            setState(() {
              userSettings.autoBackup = value;
            });
            await _saveUserSettings();
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
