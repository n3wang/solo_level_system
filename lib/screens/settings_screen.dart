// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/models/config_model.dart';
import 'package:solo_level_system/models/audio_settings_model.dart';
import 'package:solo_level_system/utils/notification_service.dart';
import 'package:solo_level_system/utils/timer_controller.dart';
import 'package:solo_level_system/widgets/palette_selector_widget.dart';
import 'package:solo_level_system/widgets/theme_mode_selector_widget.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/utils/palette_notifier.dart';
import 'package:solo_level_system/screens/workout_settings_screen.dart';
import 'package:solo_level_system/widgets/common/standard_tab_app_bar.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';
import 'package:solo_level_system/widgets/common/settings_slider.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/utils/dev_data.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/card_acquisition_settings.dart';
import 'package:solo_level_system/services/auth_service.dart';
import 'package:solo_level_system/services/solo_sync_service.dart';

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
  bool _accountBusy = false;
  bool _showSignUp = false;
  final _notificationService = NotificationService();
  final _timerController = TimerController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
      userSettings.rogueChallengeList = RogueChallengeDefaults.normalize(
        userSettings.rogueChallengeList,
        includeDev: AppEnvironment.isTest,
      );
      
      // Migrate old palette names
      if (userSettings.colorPalette == 'original' ||
          userSettings.colorPalette == 'default' ||
          userSettings.colorPalette == 'creative') {
        userSettings.colorPalette = 'pastel';
        await _saveUserSettings();
      } else if (!['grayscale', 'creative', 'pastel'].contains(userSettings.colorPalette)) {
        // If palette doesn't exist, default to pastel
        userSettings.colorPalette = 'pastel';
        await _saveUserSettings();
      }
      
      // Apply saved palette
      AppColorPalette.setActivePalette(userSettings.colorPalette);

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
      userSettings.rogueChallengeList = RogueChallengeDefaults.normalize(
        userSettings.rogueChallengeList,
        includeDev: AppEnvironment.isTest,
      );
      userSettings.sessionCompletionCardCount =
          userSettings.sessionCompletionCardCount.clamp(1, 5);
      Box<UserSettingsModel> box;
      if (!Hive.isBoxOpen('userSettings')) {
        box = await Hive.openBox<UserSettingsModel>('userSettings');
      } else {
        box = Hive.box<UserSettingsModel>('userSettings');
      }
      await box.put('settings', userSettings);
      SoloSyncService.instance.schedulePush();
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardTabAppBar(
        controller: _tabController,
        labels: const [
          'Appearance',
          'Sessions',
          'Notifications',
          'Workout',
          'Audio Config',
          'Audio Quality',
          'Account',
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppearanceTab(),
                _buildSessionsTab(),
                _buildNotificationsTab(),
                _buildWorkoutTab(),
                _buildAudioConfigTab(),
                _buildAudioQualityTab(),
                _buildAccountTab(),
              ],
            ),
    );
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Theme'),
        ThemeModeSelectorWidget(
          selectedTheme: userSettings.theme,
          onThemeSelected: (themeMode) async {
            setState(() {
              userSettings.theme = themeMode;
            });
            await _saveUserSettings();
          },
        ),
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: PaletteSelectorWidget(
            selectedPalette: userSettings.colorPalette,
            onPaletteSelected: (paletteName) async {
              setState(() {
                userSettings.colorPalette = paletteName;
              });
              AppColorPalette.setActivePalette(paletteName);
              await _saveUserSettings();
              
              // Notify palette change to trigger app-wide rebuild
              PaletteNotifier().notifyPaletteChanged(paletteName);
              
              // Show feedback
              if (mounted) {
                showAppSnack(
                  context,
                  text: 'Color palette changed to ${PaletteSelectorWidget.paletteNames[paletteName]}',
                  duration: const Duration(seconds: 1),
                );
              }
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
            width: 120,
            child: SettingsSlider(
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
            width: 120,
            child: SettingsSlider(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        Divider(),
        _buildSectionHeader('Appearance'),
        OnOffToggleListTile(
          title: Text('Color Background by Mode'),
          subtitle: Text(
            'Red background during work, green during breaks',
          ),
          value: userSettings.colorBackgroundBySessionMode,
          onChanged: (value) async {
            setState(() {
              userSettings.colorBackgroundBySessionMode = value;
            });
            await _saveUserSettings();
          },
        ),
        Divider(),
        _buildSectionHeader('Card Acquisition'),
        SettingsRectChipGroup<CardAcquisitionMode>(
          title: 'Mode',
          value: userSettings.acquisitionMode,
          options: const [
            SettingsRectChipOption(
              value: CardAcquisitionMode.sessionCompletion,
              label: 'On Session Completion',
            ),
            SettingsRectChipOption(
              value: CardAcquisitionMode.rogue,
              label: 'Rogue Cards',
            ),
            SettingsRectChipOption(
              value: CardAcquisitionMode.disabled,
              label: 'Disabled',
            ),
          ],
          onChanged: (mode) async {
            setState(() => userSettings.acquisitionMode = mode);
            await _saveUserSettings();
          },
        ),
        if (userSettings.acquisitionMode ==
            CardAcquisitionMode.sessionCompletion) ...[
          const SizedBox(height: 8),
          ListTile(
            title: Text('Cards per session'),
            subtitle: Text('${userSettings.clampedSessionCardCount}'),
            trailing: SizedBox(
              width: 120,
              child: SettingsSlider(
                value: userSettings.clampedSessionCardCount.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (value) async {
                  setState(() {
                    userSettings.sessionCompletionCardCount = value.round();
                  });
                  await _saveUserSettings();
                },
              ),
            ),
          ),
          SettingsRectChipGroup<CardAcquireTiming>(
            title: 'Acquire when',
            value: userSettings.acquireTiming,
            options: const [
              SettingsRectChipOption(
                value: CardAcquireTiming.afterBreak,
                label: 'After break',
              ),
              SettingsRectChipOption(
                value: CardAcquireTiming.afterFocus,
                label: 'After focus',
              ),
            ],
            onChanged: (timing) async {
              setState(() => userSettings.acquireTiming = timing);
              await _saveUserSettings();
            },
          ),
        ],
          const SizedBox(height: 12),
          _buildSectionHeader('Rogue challenge list'),
          Text(
            'Used when Rogue Cards is selected. Stored even if another mode is active.',
            style: TextStyle(
              color: AppColorPalette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildRogueChallengeEditors(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                setState(() {
                  userSettings.rogueChallengeList = [
                    ...userSettings.rogueChallengeList,
                    '',
                  ];
                });
                await _saveUserSettings();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add challenge'),
            ),
          ),
          if (AppEnvironment.isTest)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dev: "${RogueChallengeDefaults.netflixDevOnly}" is available in the pool.',
                style: TextStyle(
                  color: AppColorPalette.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
      ],
    );
  }

  List<Widget> _buildRogueChallengeEditors() {
    final list = userSettings.rogueChallengeList;
    return [
      for (var i = 0; i < list.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('rogue_challenge_$i'),
                  initialValue: list[i],
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: 'Challenge ${i + 1}',
                  ),
                  onChanged: (value) {
                    if (i < userSettings.rogueChallengeList.length) {
                      userSettings.rogueChallengeList[i] = value;
                    }
                  },
                  onFieldSubmitted: (_) async {
                    await _saveUserSettings();
                  },
                  onEditingComplete: () async {
                    await _saveUserSettings();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: list.length <= 2
                    ? null
                    : () async {
                        setState(() {
                          userSettings.rogueChallengeList =
                              List<String>.from(userSettings.rogueChallengeList)
                                ..removeAt(i);
                        });
                        await _saveUserSettings();
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildNotificationsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Notifications'),
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        Divider(),
        _buildSectionHeader('Developer'),
        OnOffToggleListTile(
          title: Text('Development data'),
          subtitle: Text(
            userSettings.developmentDataEnabled
                ? 'Sample projects, test rewards, and demo history are shown'
                : 'Dev samples stay in the database but are hidden from lists',
          ),
          value: userSettings.developmentDataEnabled,
          onChanged: (value) async {
            setState(() {
              userSettings.developmentDataEnabled = value;
            });
            await DevData.setEnabled(value);
            if (!mounted) return;
            showAppSnack(
              context,
              text: value
                  ? 'Development data enabled'
                  : 'Development data hidden',
            );
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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
        OnOffToggleListTile(
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

  Widget _buildWorkoutTab() {
    return WorkoutSettingsScreen();
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
            width: 120,
            child: SettingsSlider(
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
        OnOffToggleListTile(
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
            width: 120,
            child: SettingsSlider(
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
        OnOffToggleListTile(
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
            showAppSnack(
      context,
      text: 'Timer started!',
    );
          }
        },
        onPause: () {
          _timerController.pauseTimer();
          if (mounted) {
            showAppSnack(
      context,
      text: 'Timer paused!',
    );
          }
        },
        onReset: () {
          _timerController.resetTimer();
          if (mounted) {
            showAppSnack(
      context,
      text: 'Timer reset!',
    );
          }
        },
        onMute: () {
          _timerController.toggleMute();
          if (mounted) {
            showAppSnack(
      context,
      text: 'Audio toggled!',
    );
          }
        },
      );

      if (mounted) {
        showAppSnack(
          context,
          text: 'Test notification sent! Check your notification panel.',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          text: 'Failed to send notification: $e',
        );
      }
    }
  }

  Widget _buildAccountTab() {
    return ValueListenableBuilder<bool>(
      valueListenable: AccountSession.instance.loggedIn,
      builder: (context, loggedIn, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Account'),
            ListTile(
              title: Text(loggedIn ? 'Signed in' : 'Guest'),
              subtitle: Text(
                loggedIn
                    ? (AccountSession.instance.email.value ?? '')
                    : 'Data stays on this device until you sign in',
              ),
            ),
            if (_accountBusy) const LinearProgressIndicator(),
            if (!loggedIn) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_showSignUp) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _accountBusy ? null : () => _submitAccount(signUp: _showSignUp),
                child: Text(_showSignUp ? 'Create account' : 'Log in'),
              ),
              TextButton(
                onPressed: _accountBusy
                    ? null
                    : () => setState(() => _showSignUp = !_showSignUp),
                child: Text(_showSignUp
                    ? 'Have an account? Log in'
                    : 'Need an account? Sign up'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _accountBusy ? null : _googleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
            ] else
              FilledButton(
                onPressed: _accountBusy ? null : _logout,
                child: const Text('Log out'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _submitAccount({required bool signUp}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      showAppSnack(context, text: 'Email and 8+ character password required');
      return;
    }
    if (signUp && password != _confirmController.text) {
      showAppSnack(context, text: 'Passwords do not match');
      return;
    }
    setState(() => _accountBusy = true);
    try {
      if (signUp) {
        await _authService.register(email, password);
      } else {
        await _authService.login(email, password);
      }
      final synced = await SoloSyncService.instance.onLoggedIn();
      if (mounted) {
        showAppSnack(
          context,
          text: synced ? 'Signed in' : 'Signed in. Sync when online.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnack(context, text: e.toString());
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _accountBusy = true);
    try {
      await _authService.loginWithGoogle();
      final synced = await SoloSyncService.instance.onLoggedIn();
      if (mounted) {
        showAppSnack(
          context,
          text: synced ? 'Signed in with Google' : 'Signed in. Sync when online.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnack(context, text: e.toString());
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _accountBusy = true);
    try {
      await SoloSyncService.instance.logoutAndWipeStats();
      await _authService.logout();
      if (mounted) showAppSnack(context, text: 'Logged out');
    } catch (e) {
      if (mounted) showAppSnack(context, text: e.toString());
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Widget _buildPresetButtons({
    required String title,
    required List<int> values,
    required int currentValue,
    required Function(int) onSelected,
  }) {
    return SettingsRectChipGroup<int>(
      title: title,
      value: currentValue,
      onChanged: onSelected,
      options: values
          .map(
            (value) => SettingsRectChipOption(
              value: value,
              label: '${value}m',
            ),
          )
          .toList(),
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
