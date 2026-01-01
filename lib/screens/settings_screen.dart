// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';
import 'package:solo_level_system/utils/notification_service.dart';
import 'package:solo_level_system/utils/timer_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserSettingsModel userSettings = UserSettingsModel();
  ConfigModel config = ConfigModel.getDefault();
  AudioSettingsModel audioSettings = AudioSettingsModel();
  bool _isLoading = true;
  final _notificationService = NotificationService();
  final _timerController = TimerController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Load User Settings
      Box<UserSettingsModel> userBox;
      if (!Hive.isBoxOpen('userSettings')) {
        userBox = await Hive.openBox<UserSettingsModel>('userSettings');
      } else {
        userBox = Hive.box<UserSettingsModel>('userSettings');
      }
      userSettings = userBox.get('settings') ?? UserSettingsModel();
      if (userBox.get('settings') == null) {
        await userBox.put('settings', userSettings);
      }

      // Load Config Settings
      Box<ConfigModel> configBox;
      if (!Hive.isBoxOpen('config')) {
        configBox = await Hive.openBox<ConfigModel>('config');
      } else {
        configBox = Hive.box<ConfigModel>('config');
      }
      config = configBox.get('settings') ?? ConfigModel.getDefault();
      if (configBox.get('settings') == null) {
        await configBox.put('settings', config);
      }

      // Load Audio Settings
      Box<AudioSettingsModel> audioBox;
      if (!Hive.isBoxOpen('audioSettings')) {
        audioBox = await Hive.openBox<AudioSettingsModel>('audioSettings');
      } else {
        audioBox = Hive.box<AudioSettingsModel>('audioSettings');
      }
      audioSettings = audioBox.get('settings') ?? AudioSettingsModel();
      if (audioBox.get('settings') == null) {
        await audioBox.put('settings', audioSettings);
      }
    } catch (e) {
      print('Error loading settings: $e');
      userSettings = UserSettingsModel();
      config = ConfigModel.getDefault();
      audioSettings = AudioSettingsModel();
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
      if (!Hive.isBoxOpen('userSettings')) {
        box = await Hive.openBox<UserSettingsModel>('userSettings');
      } else {
        box = Hive.box<UserSettingsModel>('userSettings');
      }
      await box.put('settings', userSettings);
    } catch (e) {
      print('Error saving user settings: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      Box<ConfigModel> box;
      if (!Hive.isBoxOpen('config')) {
        box = await Hive.openBox<ConfigModel>('config');
      } else {
        box = Hive.box<ConfigModel>('config');
      }
      await box.put('settings', config);
    } catch (e) {
      print('Error saving config: $e');
    }
  }

  Future<void> _saveAudioSettings() async {
    try {
      Box<AudioSettingsModel> box;
      if (!Hive.isBoxOpen('audioSettings')) {
        box = await Hive.openBox<AudioSettingsModel>('audioSettings');
      } else {
        box = Hive.box<AudioSettingsModel>('audioSettings');
      }
      await box.put('settings', audioSettings);
    } catch (e) {
      print('Error saving audio settings: $e');
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.palette), text: 'Appearance'),
            Tab(icon: Icon(Icons.timer), text: 'Sessions'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            Tab(icon: Icon(Icons.tune), text: 'Audio Config'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio Quality'),
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
                _buildAudioConfigTab(),
                _buildAudioQualityTab(),
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
                _timerController.updateDurations(
                  userSettings.defaultWorkMinutes,
                  userSettings.defaultBreakMinutes,
                );
              },
            ),
          ),
        ),
        _buildPresetButtons(
          title: 'Quick Work Presets',
          values: [15, 25, 30, 50],
          currentValue: userSettings.defaultWorkMinutes,
          onSelected: (value) async {
            setState(() {
              userSettings.defaultWorkMinutes = value;
            });
            await _saveUserSettings();
            _timerController.updateDurations(
              userSettings.defaultWorkMinutes,
              userSettings.defaultBreakMinutes,
            );
          },
        ),
        SizedBox(height: 16),
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
                _timerController.updateDurations(
                  userSettings.defaultWorkMinutes,
                  userSettings.defaultBreakMinutes,
                );
              },
            ),
          ),
        ),
        _buildPresetButtons(
          title: 'Quick Break Presets',
          values: [1, 5, 10],
          currentValue: userSettings.defaultBreakMinutes,
          onSelected: (value) async {
            setState(() {
              userSettings.defaultBreakMinutes = value;
            });
            await _saveUserSettings();
            _timerController.updateDurations(
              userSettings.defaultWorkMinutes,
              userSettings.defaultBreakMinutes,
            );
          },
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
        _buildSectionHeader('Test Notifications'),
        ListTile(
          title: Text('Test Notification'),
          subtitle: Text('Test if notifications are working properly'),
          trailing: ElevatedButton(
            onPressed: _testNotification,
            child: Text('Test'),
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

  Widget _buildAudioConfigTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Background Audio'),
        SwitchListTile(
          title: Text('Play Audio on Repeat'),
          subtitle: Text('Loop background music continuously'),
          value: config.playAudioOnRepeat,
          onChanged: (bool value) async {
            setState(() {
              config.playAudioOnRepeat = value;
            });
            await _saveConfig();
          },
        ),
        SwitchListTile(
          title: Text('Randomize Audio'),
          subtitle: Text('Play tracks in random order instead of sequential'),
          value: config.randomizeAudio,
          onChanged: (bool value) async {
            setState(() {
              config.randomizeAudio = value;
            });
            await _saveConfig();
          },
        ),
        Divider(),
        _buildSectionHeader('Background Music Control'),
        SwitchListTile(
          title: Text('Play Audio During Work Sessions'),
          subtitle: Text(
            'Enable background music during pomodoro work sessions',
          ),
          value: userSettings.playAudioDuringWork,
          onChanged: (bool value) async {
            setState(() {
              userSettings.playAudioDuringWork = value;
            });
            await _saveUserSettings();
          },
        ),
        SwitchListTile(
          title: Text('Play Audio During Breaks'),
          subtitle: Text('Enable background music during break sessions'),
          value: userSettings.playAudioDuringBreaks,
          onChanged: (bool value) async {
            setState(() {
              userSettings.playAudioDuringBreaks = value;
            });
            await _saveUserSettings();
          },
        ),
        Divider(),
        _buildSectionHeader('Session Recording'),
        SwitchListTile(
          title: Text('Show Photo Button'),
          subtitle: Text('Allow taking photos after sessions'),
          value: config.showPhotoButton,
          onChanged: (bool value) async {
            setState(() {
              config.showPhotoButton = value;
            });
            await _saveConfig();
          },
        ),
        SwitchListTile(
          title: Text('Show Audio Recording Button'),
          subtitle: Text('Allow recording voice notes after sessions'),
          value: config.showAudioRecordButton,
          onChanged: (bool value) async {
            setState(() {
              config.showAudioRecordButton = value;
            });
            await _saveConfig();
          },
        ),
      ],
    );
  }

  Widget _buildAudioQualityTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Recording Quality'),
        ListTile(
          title: Text('Audio Codec'),
          subtitle: Text(audioSettings.codec.toUpperCase()),
          trailing: DropdownButton<String>(
            value: audioSettings.codec,
            items: [
              DropdownMenuItem(value: 'aacLc', child: Text('AAC-LC')),
              DropdownMenuItem(value: 'opus', child: Text('Opus')),
              DropdownMenuItem(value: 'wav', child: Text('WAV')),
            ],
            onChanged: (value) async {
              setState(() {
                audioSettings.codec = value!;
              });
              await _saveAudioSettings();
            },
          ),
        ),
        ListTile(
          title: Text('Bit Rate'),
          subtitle: Text('${audioSettings.bitRate} kbps'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: audioSettings.bitRate.toDouble(),
              min: 64,
              max: 256,
              divisions: 3,
              onChanged: (value) async {
                setState(() {
                  audioSettings.bitRate = value.round();
                });
                await _saveAudioSettings();
              },
            ),
          ),
        ),
        ListTile(
          title: Text('Sample Rate'),
          subtitle: Text('${audioSettings.sampleRate} Hz'),
          trailing: DropdownButton<int>(
            value: audioSettings.sampleRate,
            items: [
              DropdownMenuItem(value: 44100, child: Text('44.1 kHz')),
              DropdownMenuItem(value: 48000, child: Text('48 kHz')),
            ],
            onChanged: (value) async {
              setState(() {
                audioSettings.sampleRate = value!;
              });
              await _saveAudioSettings();
            },
          ),
        ),
        SwitchListTile(
          title: Text('Stereo Recording'),
          subtitle: Text('Record in stereo (2 channels) instead of mono'),
          value: audioSettings.channels == 2,
          onChanged: (value) async {
            setState(() {
              audioSettings.channels = value ? 2 : 1;
            });
            await _saveAudioSettings();
          },
        ),
        Divider(),
        _buildSectionHeader('Playback Settings'),
        ListTile(
          title: Text('Volume'),
          subtitle: Text('${(audioSettings.volume * 100).round()}%'),
          trailing: SizedBox(
            width: 100,
            child: Slider(
              value: audioSettings.volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) async {
                setState(() {
                  audioSettings.volume = value;
                });
                await _saveAudioSettings();
              },
            ),
          ),
        ),
        SwitchListTile(
          title: Text('Enable Noise Reduction'),
          subtitle: Text('Reduce background noise in recordings'),
          value: audioSettings.enableNoiseReduction,
          onChanged: (value) async {
            setState(() {
              audioSettings.enableNoiseReduction = value;
            });
            await _saveAudioSettings();
          },
        ),
      ],
    );
  }

  Future<void> _testNotification() async {
    try {
      await _notificationService.initialize();
      await _notificationService.showTimerNotification(
        remainingSeconds: 1500, // 25:00
        isRunning: true,
        isBreak: false,
        onPlay: () {
          _timerController.startTimer();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Timer started!')));
          }
        },
        onPause: () {
          _timerController.pauseTimer();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Timer paused!')));
          }
        },
        onReset: () {
          _timerController.resetTimer();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Timer reset!')));
          }
        },
        onMute: () {
          _timerController.toggleMute();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Audio toggled!')));
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test notification sent! Check your notification panel.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPresetButtons({
    required String title,
    required List<int> values,
    required int currentValue,
    required Function(int) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: values.map((value) {
              final isSelected = currentValue == value;
              return GestureDetector(
                onTap: () => onSelected(value),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '${value}m',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
