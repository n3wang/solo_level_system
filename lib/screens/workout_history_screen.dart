// lib/screens/workout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/models/workout_session_model.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  _WorkoutHistoryScreenState createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'all';
  String _selectedType = 'all';

  final List<String> _periods = ['all', 'week', 'month', '3months', 'year'];
  final List<String> _types = ['all', 'routine', 'custom', 'template'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _ensureBoxIsOpen<WorkoutSessionModel>('workoutSessions');
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _ensureBoxIsOpen<T>(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<T>(boxName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? LoadingIndicator(message: 'Loading workout history...')
          : Column(
              children: [
                _buildFiltersSection(),
                Expanded(child: _buildHistoryList()),
              ],
            ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomDropdownField<String>(
              value: _selectedPeriod,
              labelText: 'Time Period',
              items: _periods.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(_formatPeriodName(period)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value ?? 'all';
                });
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: CustomDropdownField<String>(
              value: _selectedType,
              labelText: 'Workout Type',
              items: _types.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_formatTypeName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? 'all';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<WorkoutSessionModel>(
        'workoutSessions',
      ).listenable(),
      builder: (context, Box<WorkoutSessionModel> box, _) {
        final allSessions = box.values.toList();
        final filteredSessions = _filterSessions(allSessions);

        if (allSessions.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: 'No Workout History',
            subtitle: 'Complete your first workout to see it here',
          );
        }

        if (filteredSessions.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No Results Found',
            subtitle: 'Try adjusting your filter criteria',
          );
        }

        // Sort sessions by date (newest first)
        filteredSessions.sort((a, b) => b.startTime.compareTo(a.startTime));

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredSessions.length,
          itemBuilder: (context, index) {
            final session = filteredSessions[index];
            return _buildSessionCard(session);
          },
        );
      },
    );
  }

  Widget _buildSessionCard(WorkoutSessionModel session) {
    final duration =
        session.endTime?.difference(session.startTime) ?? Duration.zero;
    final isCompleted = session.endTime != null;

    return BaseCard(
      onTap: () => _viewSessionDetails(session),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getSessionTypeColor(session).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getSessionTypeIcon(session),
                  color: _getSessionTypeColor(session),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSessionTitle(session),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatSessionDate(session.startTime),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'In Progress',
                      style: TextStyle(
                        color: isCompleted ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isCompleted) ...[
                    SizedBox(height: 4),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                label: 'Exercises',
                value: '${session.completedExerciseIds.length}',
                icon: Icons.fitness_center,
              ),
              SizedBox(width: 8),
              if (session.caloriesBurned > 0) ...[
                StatChip(
                  label: 'Calories',
                  value: '${session.caloriesBurned}',
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
              ],
              StatChip(
                label: 'Type',
                value: _getSessionTypeLabel(session),
                icon: Icons.category,
                color: _getSessionTypeColor(session),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<WorkoutSessionModel> _filterSessions(
    List<WorkoutSessionModel> sessions,
  ) {
    final now = DateTime.now();

    return sessions.where((session) {
      // Time period filter
      if (_selectedPeriod != 'all') {
        late DateTime cutoffDate;
        switch (_selectedPeriod) {
          case 'week':
            cutoffDate = now.subtract(Duration(days: 7));
            break;
          case 'month':
            cutoffDate = DateTime(now.year, now.month - 1, now.day);
            break;
          case '3months':
            cutoffDate = DateTime(now.year, now.month - 3, now.day);
            break;
          case 'year':
            cutoffDate = DateTime(now.year - 1, now.month, now.day);
            break;
        }
        if (session.startTime.isBefore(cutoffDate)) {
          return false;
        }
      }

      // Workout type filter
      if (_selectedType != 'all') {
        final sessionType = _getSessionType(session);
        if (sessionType != _selectedType) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatPeriodName(String period) {
    switch (period) {
      case 'all':
        return 'All Time';
      case 'week':
        return 'Last Week';
      case 'month':
        return 'Last Month';
      case '3months':
        return 'Last 3 Months';
      case 'year':
        return 'Last Year';
      default:
        return period;
    }
  }

  String _formatTypeName(String type) {
    switch (type) {
      case 'all':
        return 'All Types';
      case 'routine':
        return 'Routine';
      case 'custom':
        return 'Custom';
      case 'template':
        return 'Template';
      default:
        return type;
    }
  }

  String _getSessionTitle(WorkoutSessionModel session) {
    if (session.routineName.isNotEmpty == true) {
      return session.routineName;
    }
    return 'Custom Workout';
  }

  String _getSessionType(WorkoutSessionModel session) {
    if (session.routineName.isNotEmpty == true) {
      return 'routine';
    }
    return 'custom';
  }

  String _getSessionTypeLabel(WorkoutSessionModel session) {
    return _getSessionType(session) == 'routine' ? 'Routine' : 'Custom';
  }

  Color _getSessionTypeColor(WorkoutSessionModel session) {
    return _getSessionType(session) == 'routine' ? Colors.blue : Colors.purple;
  }

  IconData _getSessionTypeIcon(WorkoutSessionModel session) {
    return _getSessionType(session) == 'routine' ? Icons.list : Icons.build;
  }

  String _formatSessionDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _viewSessionDetails(WorkoutSessionModel session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CustomBottomSheet(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getSessionTitle(session),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Started: ${_formatSessionDate(session.startTime)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (session.endTime != null) ...[
              Text(
                'Duration: ${_formatDuration(session.endTime!.difference(session.startTime))}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
            SizedBox(height: 16),
            _buildDetailRow(
              'Exercises Completed',
              '${session.completedExerciseIds.length}',
            ),
            if (session.caloriesBurned > 0)
              _buildDetailRow('Calories Burned', '${session.caloriesBurned}'),
            _buildDetailRow('Workout Type', _getSessionTypeLabel(session)),
            if (session.notes?.isNotEmpty == true) ...[
              SizedBox(height: 16),
              Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(session.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
