// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserSettingsModel userSettings;
  late AudioSettingsModel audioSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  void _loadSettings() {
    final userBox = Hive.box<UserSettingsModel>('userSettings');
    final audioBox = Hive.box<AudioSettingsModel>('audioSettings');

    // Get existing settings or create defaults
    userSettings = userBox.get('settings') ?? UserSettingsModel();
    audioSettings = audioBox.get('settings') ?? AudioSettingsModel();

    // Save defaults if they don't exist
    if (userBox.get('settings') == null) {
      userBox.put('settings', userSettings);
    }
    if (audioBox.get('settings') == null) {
      audioBox.put('settings', audioSettings);
    }
  }

  void _saveUserSettings() {
    final box = Hive.box<UserSettingsModel>('userSettings');
    box.put('settings', userSettings);
  }

  void _saveAudioSettings() {
    final box = Hive.box<AudioSettingsModel>('audioSettings');
    box.put('settings', audioSettings);
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
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppearanceTab(),
          _buildSessionsTab(),
          _buildAudioTab(),
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
            value: userSettings.theme,
            items: [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.theme = value!;
                _saveUserSettings();
              });
            },
          ),
        ),
        ListTile(
          title: Text('Primary Color'),
          subtitle: Text('Choose your accent color'),
          trailing: DropdownButton<String>(
            value: userSettings.primaryColor,
            items: [
              DropdownMenuItem(value: 'red', child: Text('Red')),
              DropdownMenuItem(value: 'blue', child: Text('Blue')),
              DropdownMenuItem(value: 'green', child: Text('Green')),
              DropdownMenuItem(value: 'purple', child: Text('Purple')),
              DropdownMenuItem(value: 'orange', child: Text('Orange')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.primaryColor = value!;
                _saveUserSettings();
              });
            },
          ),
        ),
        Divider(),
        _buildSectionHeader('Localization'),
        ListTile(
          title: Text('Language'),
          subtitle: Text('Choose your language'),
          trailing: DropdownButton<String>(
            value: userSettings.language,
            items: [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'es', child: Text('Español')),
              DropdownMenuItem(value: 'fr', child: Text('Français')),
              DropdownMenuItem(value: 'de', child: Text('Deutsch')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.language = value!;
                _saveUserSettings();
              });
            },
          ),
        ),
        ListTile(
          title: Text('Date Format'),
          trailing: DropdownButton<String>(
            value: userSettings.dateFormat,
            items: [
              DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy')),
              DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy')),
              DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.dateFormat = value!;
                _saveUserSettings();
              });
            },
          ),
        ),
        ListTile(
          title: Text('Time Format'),
          trailing: DropdownButton<String>(
            value: userSettings.timeFormat,
            items: [
              DropdownMenuItem(value: '12h', child: Text('12 Hour')),
              DropdownMenuItem(value: '24h', child: Text('24 Hour')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.timeFormat = value!;
                _saveUserSettings();
              });
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
              onChanged: (value) {
                setState(() {
                  userSettings.defaultWorkMinutes = value.round();
                  _saveUserSettings();
                });
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
              onChanged: (value) {
                setState(() {
                  userSettings.defaultBreakMinutes = value.round();
                  _saveUserSettings();
                });
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
          onChanged: (value) {
            setState(() {
              userSettings.autoStartBreaks = value;
              _saveUserSettings();
            });
          },
        ),
        SwitchListTile(
          title: Text('Auto-start Work'),
          subtitle: Text('Automatically start work timer after break'),
          value: userSettings.autoStartWork,
          onChanged: (value) {
            setState(() {
              userSettings.autoStartWork = value;
              _saveUserSettings();
            });
          },
        ),
      ],
    );
  }

  Widget _buildAudioTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Recording Quality'),
        ListTile(
          title: Text('Audio Quality'),
          subtitle: Text(audioSettings.qualityDescription),
          trailing: DropdownButton<String>(
            value: audioSettings.codec,
            items: [
              DropdownMenuItem(value: 'aacLc', child: Text('AAC-LC (Best)')),
              DropdownMenuItem(value: 'opus', child: Text('Opus (Efficient)')),
              DropdownMenuItem(value: 'wav', child: Text('WAV (Uncompressed)')),
            ],
            onChanged: (value) {
              setState(() {
                audioSettings.codec = value!;
                _saveAudioSettings();
              });
            },
          ),
        ),
        ListTile(
          title: Text('Bit Rate'),
          subtitle: Text('${audioSettings.bitRate} kbps'),
          trailing: DropdownButton<int>(
            value: audioSettings.bitRate,
            items: [
              DropdownMenuItem(value: 64, child: Text('64 kbps')),
              DropdownMenuItem(value: 128, child: Text('128 kbps')),
              DropdownMenuItem(value: 256, child: Text('256 kbps')),
              DropdownMenuItem(value: 320, child: Text('320 kbps')),
            ],
            onChanged: (value) {
              setState(() {
                audioSettings.bitRate = value!;
                _saveAudioSettings();
              });
            },
          ),
        ),
        ListTile(
          title: Text('Channels'),
          trailing: DropdownButton<int>(
            value: audioSettings.channels,
            items: [
              DropdownMenuItem(value: 1, child: Text('Mono')),
              DropdownMenuItem(value: 2, child: Text('Stereo')),
            ],
            onChanged: (value) {
              setState(() {
                audioSettings.channels = value!;
                _saveAudioSettings();
              });
            },
          ),
        ),
        Divider(),
        _buildSectionHeader('Playback'),
        ListTile(
          title: Text('Default Playback Speed'),
          subtitle: Text('${audioSettings.playbackSpeed}x'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: audioSettings.playbackSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) {
                setState(() {
                  audioSettings.playbackSpeed = value;
                  _saveAudioSettings();
                });
              },
            ),
          ),
        ),
        ListTile(
          title: Text('Default Volume'),
          subtitle: Text('${(audioSettings.volume * 100).round()}%'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: audioSettings.volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  audioSettings.volume = value;
                  _saveAudioSettings();
                });
              },
            ),
          ),
        ),
        Divider(),
        _buildSectionHeader('Processing'),
        SwitchListTile(
          title: Text('Noise Reduction'),
          subtitle: Text('Reduce background noise in recordings'),
          value: audioSettings.enableNoiseReduction,
          onChanged: (value) {
            setState(() {
              audioSettings.enableNoiseReduction = value;
              _saveAudioSettings();
            });
          },
        ),
        SwitchListTile(
          title: Text('Auto Gain Control'),
          subtitle: Text('Automatically adjust recording levels'),
          value: audioSettings.enableAutoGain,
          onChanged: (value) {
            setState(() {
              audioSettings.enableAutoGain = value;
              _saveAudioSettings();
            });
          },
        ),
        SwitchListTile(
          title: Text('Show Waveform'),
          subtitle: Text('Display audio waveform during playback'),
          value: audioSettings.showWaveform,
          onChanged: (value) {
            setState(() {
              audioSettings.showWaveform = value;
              _saveAudioSettings();
            });
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
          onChanged: (value) {
            setState(() {
              userSettings.enableNotifications = value;
              _saveUserSettings();
            });
          },
        ),
        SwitchListTile(
          title: Text('Enable Sounds'),
          subtitle: Text('Play notification sounds'),
          value: userSettings.enableSounds,
          onChanged: (value) {
            setState(() {
              userSettings.enableSounds = value;
              _saveUserSettings();
            });
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
              DropdownMenuItem(value: 'notification', child: Text('Notification')),
            ],
            onChanged: (value) {
              setState(() {
                userSettings.notificationSound = value!;
                _saveUserSettings();
              });
            },
          ),
        ),
        Divider(),
        _buildSectionHeader('Privacy'),
        SwitchListTile(
          title: Text('Enable Analytics'),
          subtitle: Text('Help improve the app by sharing usage data'),
          value: userSettings.enableAnalytics,
          onChanged: (value) {
            setState(() {
              userSettings.enableAnalytics = value;
              _saveUserSettings();
            });
          },
        ),
        SwitchListTile(
          title: Text('Auto Backup'),
          subtitle: Text('Automatically backup your data'),
          value: userSettings.autoBackup,
          onChanged: (value) {
            setState(() {
              userSettings.autoBackup = value;
              _saveUserSettings();
            });
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
