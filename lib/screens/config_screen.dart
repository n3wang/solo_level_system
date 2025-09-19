import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/config_model.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late ConfigModel config;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final box = await Hive.openBox<ConfigModel>('config');
    config = box.get('settings') ?? ConfigModel.getDefault();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    final box = await Hive.openBox<ConfigModel>('config');
    await box.put('settings', config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Configuration')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuration'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Play Audio on Repeat'),
                      subtitle: Text('Loop background music continuously'),
                      value: config.playAudioOnRepeat,
                      onChanged: (bool value) {
                        setState(() {
                          config.playAudioOnRepeat = value;
                        });
                      },
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('Randomize Audio'),
                      subtitle: Text('Play tracks in random order instead of sequential'),
                      value: config.randomizeAudio,
                      onChanged: (bool value) {
                        setState(() {
                          config.randomizeAudio = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Session Recording',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Show Photo Button'),
                      subtitle: Text('Allow taking photos after sessions'),
                      value: config.showPhotoButton,
                      onChanged: (bool value) {
                        setState(() {
                          config.showPhotoButton = value;
                        });
                      },
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('Show Audio Recording Button'),
                      subtitle: Text('Allow recording voice notes after sessions'),
                      value: config.showAudioRecordButton,
                      onChanged: (bool value) {
                        setState(() {
                          config.showAudioRecordButton = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveConfig,
                child: Text('Save Settings'),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    config = ConfigModel.getDefault();
                  });
                },
                child: Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}