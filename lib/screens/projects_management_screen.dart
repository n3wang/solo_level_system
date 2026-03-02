// lib/screens/projects_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class ProjectsManagementScreen extends StatefulWidget {
  const ProjectsManagementScreen({super.key});

  @override
  _ProjectsManagementScreenState createState() =>
      _ProjectsManagementScreenState();
}

class _ProjectsManagementScreenState extends State<ProjectsManagementScreen> {
  List<ProjectModel> projects = [];
  bool isLoading = true;
  bool _showArchived = false;
  ProjectModel? _selectedProject;
  int _dailyTarget = 1;
  int _weeklyTarget = 2;
  int _workDuration = 25;
  int _breakDuration = 5;
  final Map<int, int> _dayStates = {for (int day = 1; day <= 7; day++) day: 0};
  TimeOfDay _morningStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _afternoonStart = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _eveningStart = const TimeOfDay(hour: 18, minute: 30);
  bool _sendNotification = false;
  bool _showOnlyWithinHour = false;
  bool _dontScoreOutside = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      print('Loading projects...');

      if (!Hive.isBoxOpen('projects')) {
        print('Projects box not open, opening it...');
        await Hive.openBox<ProjectModel>('projects');
      }

      final box = Hive.box<ProjectModel>('projects');
      projects = box.values.toList();

      print('Loaded ${projects.length} projects');
      for (var project in projects) {
        print('Project: ${project.name}');
      }

      setState(() {
        final filtered = _filteredProjects;
        if (_selectedProject != null &&
            !filtered.any((p) => p.id == _selectedProject!.id)) {
          _selectedProject = null;
        }
        if (_selectedProject == null && filtered.isNotEmpty) {
          _selectedProject = filtered.first;
        }
        _syncEditorFromSelectedProject();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading projects: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabbedScreenWrapper(
      isLoading: isLoading,
      loadingMessage: 'Loading projects...',
      builder: () => _buildContent(),
    );
  }

  Widget _buildContent() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showArchived = !_showArchived;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: Icon(_showArchived ? Icons.archive : Icons.folder_open),
              label: Text(_showArchived ? 'Archived' : 'Active'),
            ),
            const SizedBox(width: 10),
            Text(_showArchived ? 'Projects (Archived)' : 'Projects'),
          ],
        ),
      ),
      body: _buildEditorLayout(),
    );
  }

  List<ProjectModel> get _filteredProjects => _showArchived
      ? projects.where((p) => !p.isActive).toList()
      : projects.where((p) => p.isActive).toList();

  void _syncEditorFromSelectedProject() {
    final p = _selectedProject;
    if (p == null) {
      _dailyTarget = 1;
      _weeklyTarget = 2;
      _workDuration = 25;
      _breakDuration = 5;
      for (int day = 1; day <= 7; day++) {
        _dayStates[day] = 0;
      }
      return;
    }
    _dailyTarget = p.dailySessionTarget;
    _weeklyTarget = p.weeklySessionTarget;
    _workDuration = p.workDurationMinutes;
    _breakDuration = p.breakDurationMinutes;
    final preferred = p.preferredWorkHour ?? 9;
    _morningStart = TimeOfDay(hour: preferred, minute: 0);
    for (int day = 1; day <= 7; day++) {
      _dayStates[day] = p.activeDays.contains(day) ? 0 : 1;
    }
  }

  Future<void> _persistSelectedProject() async {
    final p = _selectedProject;
    if (p == null) return;
    p.dailySessionTarget = _dailyTarget;
    p.weeklySessionTarget = _weeklyTarget;
    p.workDurationMinutes = _workDuration;
    p.breakDurationMinutes = _breakDuration;
    p.preferredWorkHour = _morningStart.hour;
    p.activeDays = _dayStates.entries
        .where((entry) => entry.value != 1)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    await p.save();
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildEditorLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProjectPreviewCard(),
          const SizedBox(height: 14),
          _buildProjectSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildProjectPreviewCard() {
    final selected = _selectedProject;
    final name = selected?.name ?? 'No Project';
    final description = selected?.description ?? 'No description yet';
    final isActiveList = !_showArchived;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showArchived = !_showArchived;
                        final filtered = _filteredProjects;
                        if (_selectedProject != null &&
                            !filtered.any((p) => p.id == _selectedProject!.id)) {
                          _selectedProject = null;
                        }
                        if (_selectedProject == null && filtered.isNotEmpty) {
                          _selectedProject = filtered.first;
                        }
                        _syncEditorFromSelectedProject();
                      });
                    },
                    child: Text(_showArchived ? 'archived' : 'active'),
                  ),
                ),
                const Spacer(),
                _buildMiniActionButton(
                  icon: isActiveList ? Icons.archive_outlined : Icons.unarchive_outlined,
                  tooltip: isActiveList ? 'Archive selected project' : 'Restore selected project',
                  onPressed: _selectedProject == null
                      ? null
                      : () async {
                          if (isActiveList) {
                            _selectedProject!.archive();
                          } else {
                            _selectedProject!.unarchive();
                          }
                          await _loadProjects();
                        },
                ),
                const SizedBox(width: 6),
                _buildMiniActionButton(
                  icon: Icons.add,
                  tooltip: 'Create project',
                  onPressed: _showCreateProjectDialog,
                ),
                const SizedBox(width: 6),
                _buildMiniActionButton(
                  icon: Icons.casino_outlined,
                  tooltip: 'Random project',
                  onPressed: () {
                    final filtered = _filteredProjects;
                    if (filtered.isEmpty) return;
                    filtered.shuffle();
                    setState(() {
                      _selectedProject = filtered.first;
                      _syncEditorFromSelectedProject();
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildMiniActionButton(
                  icon: Icons.close,
                  tooltip: 'No project',
                  onPressed: () {
                    setState(() {
                      _selectedProject = null;
                      _syncEditorFromSelectedProject();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26),
              ),
              child: Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Project'),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 5,
                  children: [
                    for (int i = 0; i <= _filteredProjects.length; i++)
                      _buildProjectIndicator(i),
                  ],
                ),
                const Spacer(),
                const Text('Breakdown'),
                const SizedBox(width: 8),
                _buildBreakdownBars(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildProjectIndicator(int index) {
    final project = index == 0 ? null : _filteredProjects[index - 1];
    final selected = (project == null && _selectedProject == null) ||
        (project?.id == _selectedProject?.id);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProject = project;
          _syncEditorFromSelectedProject();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 10,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.grey.shade600, width: 1.4),
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildBreakdownBars() {
    return Wrap(
      spacing: 3,
      children: [
        ...List.generate(
          (_workDuration / 5).ceil(),
          (_) => _buildBreakdownBar(Colors.red),
        ),
        ...List.generate(
          (_breakDuration / 5).ceil(),
          (_) => _buildBreakdownBar(Colors.green),
        ),
      ],
    );
  }

  Widget _buildBreakdownBar(Color color) {
    return Container(
      width: 9,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildProjectSettingsCard() {
    final bool enabled = _selectedProject != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session Targets',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCounterField(
                        label: 'Daily',
                        value: _dailyTarget,
                        min: 1,
                        max: 20,
                        onChanged: (v) async {
                          setState(() => _dailyTarget = v);
                          await _persistSelectedProject();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCounterField(
                        label: 'Weekly',
                        value: _weeklyTarget,
                        min: 1,
                        max: 50,
                        onChanged: (v) async {
                          setState(() => _weeklyTarget = v);
                          await _persistSelectedProject();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Active Days', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int day = 1; day <= 7; day++)
                          GestureDetector(
                            onTap: () async {
                              setState(() {
                                _dayStates[day] = _nextDayState(_dayStates[day] ?? 0);
                              });
                              await _persistSelectedProject();
                            },
                            child: _buildDayStateRect(_dayStates[day] ?? 0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int day = 1; day <= 7; day++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${_getDayName(day)}, ${_dayStateLabel(_dayStates[day] ?? 0)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Work Hour (Optional)', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTimeField('Morning', _morningStart)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeField('Afternoon', _afternoonStart)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeField('Evening', _eveningStart)),
                  ],
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _sendNotification,
                  onChanged: (v) => setState(() => _sendNotification = v ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Create Notification'),
                ),
                CheckboxListTile(
                  value: _showOnlyWithinHour,
                  onChanged: (v) => setState(() => _showOnlyWithinHour = v ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Show only within 1 hour of target'),
                ),
                CheckboxListTile(
                  value: _dontScoreOutside,
                  onChanged: (v) => setState(() => _dontScoreOutside = v ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Dont Score project if outside of hour range'),
                ),
                const SizedBox(height: 10),
                const Text('Session Duration (minutes)', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCounterField(
                        label: 'Work Duration',
                        value: _workDuration,
                        min: 5,
                        max: 180,
                        step: 5,
                        onChanged: (v) async {
                          setState(() => _workDuration = v);
                          await _persistSelectedProject();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCounterField(
                        label: 'Break',
                        value: _breakDuration,
                        min: 5,
                        max: 60,
                        step: 5,
                        onChanged: (v) async {
                          setState(() => _breakDuration = v);
                          await _persistSelectedProject();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterField({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - step) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black26),
              ),
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + step) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, TimeOfDay value) {
    final text = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showCreateProjectDialog() {
    _showProjectDialog();
  }

  void _showProjectDialog({ProjectModel? project}) {
    final isEditing = project != null;
    final nameController = TextEditingController(text: project?.name ?? '');
    final descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    String selectedColor = project?.color ?? '#2196F3';
    String selectedIcon = project?.iconName ?? 'folder';
    int selectedPriority = project?.priority ?? 1;
    String selectedTargetType = project?.targetType ?? 'daily';
    int selectedDailyTarget = project?.dailySessionTarget ?? 1;
    int selectedWeeklyTarget = project?.weeklySessionTarget ?? 2;
    int? selectedWorkHour = project?.preferredWorkHour;
    List<int> selectedActiveDays = List.from(
      project?.activeDays ?? [1, 2, 3, 4, 5, 6, 7],
    );
    final Map<int, int> selectedDayStates = {
      for (int day = 1; day <= 7; day++)
        day: selectedActiveDays.contains(day) ? 0 : 1,
    };
    final dailyTargetController = TextEditingController(
      text: selectedDailyTarget.toString(),
    );
    final weeklyTargetController = TextEditingController(
      text: selectedWeeklyTarget.toString(),
    );
    int selectedWorkDuration = project?.workDurationMinutes ?? 25;
    int selectedBreakDuration = project?.breakDurationMinutes ?? 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Project' : 'Create New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MOST IMPORTANT FIELDS FIRST
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g., "Learn Flutter"',
                  ),
                ),
                SizedBox(height: 20),

                // Daily Session Target - Second most important
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (selectedDailyTarget > 1) {
                                          selectedDailyTarget--;
                                          dailyTargetController.text =
                                              selectedDailyTarget.toString();
                                        }
                                      });
                                    },
                                    icon: Icon(Icons.remove_circle_outline),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: TextField(
                                      controller: dailyTargetController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final parsed = int.tryParse(value);
                                        if (parsed != null && parsed > 0) {
                                          selectedDailyTarget = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (selectedDailyTarget < 20) {
                                          selectedDailyTarget++;
                                          dailyTargetController.text =
                                              selectedDailyTarget.toString();
                                        }
                                      });
                                    },
                                    icon: Icon(Icons.add_circle_outline),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (selectedWeeklyTarget > 1) {
                                          selectedWeeklyTarget--;
                                          weeklyTargetController.text =
                                              selectedWeeklyTarget.toString();
                                        }
                                      });
                                    },
                                    icon: Icon(Icons.remove_circle_outline),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: TextField(
                                      controller: weeklyTargetController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final parsed = int.tryParse(value);
                                        if (parsed != null && parsed > 0) {
                                          selectedWeeklyTarget = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (selectedWeeklyTarget < 50) {
                                          selectedWeeklyTarget++;
                                          weeklyTargetController.text =
                                              selectedWeeklyTarget.toString();
                                        }
                                      });
                                    },
                                    icon: Icon(Icons.add_circle_outline),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Active Days (cycle states)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int day = 1; day <= 7; day++)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedDayStates[day] = _nextDayState(
                                      selectedDayStates[day] ?? 0,
                                    );
                                  });
                                },
                                child: _buildDayStateRect(
                                  selectedDayStates[day] ?? 0,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int day = 1; day <= 7; day++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${_getDayName(day)}: ${_dayStateLabel(selectedDayStates[day] ?? 0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // DIVIDER FOR LESS IMPORTANT SETTINGS
                Divider(thickness: 1),
                Text(
                  'Additional Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16),

                // Less important fields below
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of your project',
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedPriority,
                  decoration: InputDecoration(labelText: 'Priority'),
                  items: [
                    DropdownMenuItem(value: 1, child: Text('Low')),
                    DropdownMenuItem(value: 2, child: Text('Medium')),
                    DropdownMenuItem(value: 3, child: Text('High')),
                    DropdownMenuItem(value: 4, child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    if (value != null) selectedPriority = value;
                  },
                ),
                SizedBox(height: 16),
                // Preferred Work Hour
                DropdownButtonFormField<int?>(
                  dropdownColor: Theme.of(context).canvasColor,
                  initialValue: selectedWorkHour,
                  decoration: InputDecoration(
                    labelText: 'Preferred Work Hour (Optional)',
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No preference'),
                    ),
                    for (int hour = 0; hour < 24; hour++)
                      DropdownMenuItem<int?>(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedWorkHour = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                // Work Session Duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Session Duration (minutes)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedWorkDuration > 5) {
                                selectedWorkDuration -= 5;
                              }
                            });
                          },
                          icon: Icon(Icons.remove_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selectedWorkDuration min',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedWorkDuration < 60) {
                                selectedWorkDuration += 5;
                              }
                            });
                          },
                          icon: Icon(Icons.add_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Break Session Duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break Duration (minutes)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedBreakDuration > 5) {
                                selectedBreakDuration -= 5;
                              }
                            });
                          },
                          icon: Icon(Icons.remove_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selectedBreakDuration min',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (selectedBreakDuration < 60) {
                                selectedBreakDuration += 5;
                              }
                            });
                          },
                          icon: Icon(Icons.add_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...List.generate(
                      (selectedWorkDuration / 5).ceil(),
                      (_) => Container(
                        width: 12,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade300),
                          color: Colors.red.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    ...List.generate(
                      (selectedBreakDuration / 5).ceil(),
                      (_) => Container(
                        width: 12,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300),
                          color: Colors.green.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ],
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
                if (nameController.text.isNotEmpty) {
                  selectedActiveDays = selectedDayStates.entries
                      .where((entry) => entry.value != 1)
                      .map((entry) => entry.key)
                      .toList()
                    ..sort();
                  if (isEditing) {
                    project.name = nameController.text;
                    project.description = descriptionController.text;
                    project.priority = selectedPriority;
                    project.targetType = selectedTargetType;
                    project.dailySessionTarget = selectedDailyTarget;
                    project.weeklySessionTarget = selectedWeeklyTarget;
                    project.preferredWorkHour = selectedWorkHour;
                    project.activeDays = selectedActiveDays;
                    project.workDurationMinutes = selectedWorkDuration;
                    project.breakDurationMinutes = selectedBreakDuration;
                    project.save();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Project updated!')));
                  } else {
                    _createProject(
                      nameController.text,
                      descriptionController.text,
                      selectedColor,
                      selectedIcon,
                      selectedPriority,
                      selectedTargetType,
                      selectedDailyTarget,
                      selectedWeeklyTarget,
                      selectedWorkHour,
                      selectedActiveDays,
                      selectedWorkDuration,
                      selectedBreakDuration,
                    );
                  }
                  Navigator.of(context).pop();
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProject(
    String name,
    String description,
    String color,
    String icon,
    int priority,
    String targetType,
    int dailyTarget,
    int weeklyTarget,
    int? workHour,
    List<int> activeDays,
    int workDuration,
    int breakDuration,
  ) async {
    try {
      print('Creating project with name: $name');

      final project = ProjectModel(
        id: 'project_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description,
        color: color,
        iconName: icon,
        priority: priority,
        targetType: targetType,
        dailySessionTarget: dailyTarget,
        weeklySessionTarget: weeklyTarget,
        preferredWorkHour: workHour,
        activeDays: activeDays,
        workDurationMinutes: workDuration,
        breakDurationMinutes: breakDuration,
        createdAt: DateTime.now(),
      );

      print('Project object created successfully');

      // Ensure the box is open
      if (!Hive.isBoxOpen('projects')) {
        await Hive.openBox<ProjectModel>('projects');
        print('Opened projects box');
      }

      final box = Hive.box<ProjectModel>('projects');
      await box.add(project);
      print('Project saved to Hive');

      setState(() {
        projects.add(project);
      });

      print('UI updated with new project');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🎉 Project created!')));
    } catch (e) {
      print('Error creating project: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating project: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  int _nextDayState(int current) => (current + 1) % 5;

  String _dayStateLabel(int state) {
    switch (state) {
      case 0:
        return 'Active';
      case 1:
        return 'Not active';
      case 2:
        return 'Morning only';
      case 3:
        return 'Afternoon only';
      case 4:
        return 'Evening only';
      default:
        return 'Active';
    }
  }

  Widget _buildDayStateRect(int state) {
    final borderColor = Colors.grey.shade600;
    Widget fillFor(double top, double height) {
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        height: height,
        child: Container(color: Theme.of(context).colorScheme.primary),
      );
    }

    return SizedBox(
      width: 20,
      height: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 1.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (state == 0) fillFor(0, 36),
            if (state == 2) fillFor(0, 12),
            if (state == 3) fillFor(12, 12),
            if (state == 4) fillFor(24, 12),
          ],
        ),
      ),
    );
  }
}
