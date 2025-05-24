import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/widgets/audio_player.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<String> tags = ['Today', 'Yesterday', 'This Week'];
  String selectedTag = 'Today';

  List<PomodoroModel> _filterSessions(List<PomodoroModel> all) {
    final now = DateTime.now();
    return all.where((session) {
      final time = session.startTime;
      switch (selectedTag) {
        case 'Today':
          return time.year == now.year &&
              time.month == now.month &&
              time.day == now.day;
        case 'Yesterday':
          final yesterday = now.subtract(Duration(days: 1));
          return time.year == yesterday.year &&
              time.month == yesterday.month &&
              time.day == yesterday.day;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return time.isAfter(startOfWeek);
        default:
          return true;
      }
    }).toList();
  }

  void _showDetails(PomodoroModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Pomodoro Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imagePath != null && File(item.imagePath!).existsSync())
              Image.file(File(item.imagePath!), height: 200),
            if (item.audioPath != null)
              AudioPlayer(
                source: item.audioPath!,
                onDelete: () {}, // No deletion from history
              ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<PomodoroModel>('pomodoros');

    return Scaffold(
      appBar: AppBar(title: Text('History')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<PomodoroModel> box, _) {
          final filtered = _filterSessions(box.values.toList());

          return Column(
            children: [
              SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tags.map((tag) {
                    final isSelected = selectedTag == tag;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (_) => setState(() => selectedTag = tag),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text("No sessions found."))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          return ListTile(
                            title: Text(
                              DateFormat.yMMMd().add_jm().format(
                                item.startTime,
                              ),
                            ),
                            onTap: () => _showDetails(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
