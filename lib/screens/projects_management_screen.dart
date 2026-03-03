// lib/screens/projects_management_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/widgets/common/index.dart';

class ProjectsManagementScreen extends StatefulWidget {
  final String? initialSelectedProjectId;

  const ProjectsManagementScreen({
    super.key,
    this.initialSelectedProjectId,
  });

  @override
  _ProjectsManagementScreenState createState() =>
      _ProjectsManagementScreenState();
}

class _ProjectsManagementScreenState extends State<ProjectsManagementScreen> {
  static const List<String> _supportedVisualExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];
  List<ProjectModel> projects = [];
  bool isLoading = true;
  bool _showArchived = false;
  late final PageController _projectPageController;
  final ImagePicker _imagePicker = ImagePicker();
  ProjectModel? _selectedProject;
  int _dailyTarget = 1;
  int _weeklyTarget = 2;
  int _workDuration = 25;
  int _breakDuration = 5;
  final Map<int, int> _dayStates = {for (int day = 1; day <= 7; day++) day: 0};
  TimeOfDay _morningStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _afternoonStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _eveningStart = const TimeOfDay(hour: 18, minute: 30);
  bool _sendNotification = false;
  bool _showOnlyWithinHour = false;
  bool _dontScoreOutside = false;

  @override
  void initState() {
    super.initState();
    _projectPageController = PageController(viewportFraction: 0.88);
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
        if (_selectedProject == null && widget.initialSelectedProjectId != null) {
          for (final project in filtered) {
            if (project.id == widget.initialSelectedProjectId) {
              _selectedProject = project;
              break;
            }
          }
        }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerSelectedProjectCard(_selectedProject);
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
    _projectPageController.dispose();
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: _selectedProject == null
              ? 'Close project management'
              : 'Back to home with selected project',
          onPressed: () => Navigator.of(context).pop(_selectedProject?.id),
          icon: Icon(
            _selectedProject == null ? Icons.close : Icons.arrow_upward,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            TextButton.icon(
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
                _centerSelectedProjectCard(_selectedProject);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              icon: Icon(_showArchived ? Icons.archive : Icons.folder_open),
              label: Text(_showArchived ? 'Archived Project' : 'Active Project'),
            ),
          ],
        ),
      ),
      body: _buildEditorLayout(),
    );
  }

  List<ProjectModel> get _filteredProjects => _showArchived
      ? projects.where((p) => !p.isActive).toList()
      : projects.where((p) => p.isActive).toList();

  bool get _canRandomProjectRoll => _filteredProjects.length > 1;

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
    p.activeDays =
        _dayStates.entries
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
          const SizedBox(height: 16),
          _buildProjectSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildProjectPreviewCard() {
    final isActiveList = !_showArchived;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    height: 112,
                    child: PageView.builder(
                      controller: _projectPageController,
                      itemCount: _filteredProjects.length + 1,
                      onPageChanged: (index) {
                        final project = index == 0
                            ? null
                            : _filteredProjects[index - 1];
                        setState(() {
                          _selectedProject = project;
                          _syncEditorFromSelectedProject();
                        });
                      },
                      itemBuilder: (context, index) {
                        final project = index == 0
                            ? null
                            : _filteredProjects[index - 1];
                        final projectName = project?.name ?? 'No Project';
                        final projectDescription =
                            project?.description ?? 'No description yet';
                        final selectedCard =
                            (project == null && _selectedProject == null) ||
                            project?.id == _selectedProject?.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final alreadySelected =
                                  (project == null &&
                                      _selectedProject == null) ||
                                  (project?.id == _selectedProject?.id);
                              if (alreadySelected) {
                                await _centerSelectedProjectCard(project);
                                await _showProjectInfoModal(project);
                                return;
                              }
                              setState(() {
                                _selectedProject = project;
                                _syncEditorFromSelectedProject();
                              });
                              await _centerSelectedProjectCard(project);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedCard
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade400,
                                  width: selectedCard ? 2 : 1,
                                ),
                                color: selectedCard
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    projectName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    projectDescription,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _selectedProject == null
                                ? null
                                : () async {
                                    if (isActiveList) {
                                      await _archiveSelectedProjectWithNearestFallback();
                                    } else {
                                      _selectedProject!.unarchive();
                                      await _loadProjects();
                                    }
                                  },
                            child: Icon(
                              isActiveList
                                  ? Icons.archive_outlined
                                  : Icons.unarchive_outlined,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _showCreateProjectDialog,
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ),
                        if (_canRandomProjectRoll) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final candidates = _filteredProjects
                                    .where((p) => p.id != _selectedProject?.id)
                                    .toList();
                                if (candidates.isEmpty) return;
                                candidates.shuffle();
                                final pick = candidates.first;
                                setState(() {
                                  _selectedProject = pick;
                                  _syncEditorFromSelectedProject();
                                });
                                await _centerSelectedProjectCard(pick);
                              },
                              child: const Icon(
                                Icons.casino_outlined,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              setState(() {
                                _selectedProject = null;
                                _syncEditorFromSelectedProject();
                              });
                              await _centerSelectedProjectCard(null);
                            },
                            child: const Icon(
                              Icons.folder_off_outlined,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (int i = 0; i <= _filteredProjects.length; i++)
                                _buildProjectIndicator(i),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Breakdown',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    _buildBreakdownBars(),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectIndicator(int index) {
    final project = index == 0 ? null : _filteredProjects[index - 1];
    final selected =
        (project == null && _selectedProject == null) ||
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
        width: 12,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.grey.shade600, width: 1.5),
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
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
      width: 12,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        color: color.withValues(alpha: 0.02),
      ),
    );
  }

  Widget _buildProjectSettingsCard() {
    final bool enabled = _selectedProject != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Session Targets',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active Days',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    Text(
                      _activeDaysSummaryText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Work Hour (Optional)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeField('Morning', _morningStart, (v) async {
                            setState(() => _morningStart = v);
                            await _persistSelectedProject();
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField(
                            'Afternoon',
                            _afternoonStart,
                            (v) => setState(() => _afternoonStart = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField(
                            'Evening',
                            _eveningStart,
                            (v) => setState(() => _eveningStart = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _sendNotification,
                      onChanged: (v) => setState(() => _sendNotification = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Create Notification'),
                    ),
                    CheckboxListTile(
                      value: _showOnlyWithinHour,
                      onChanged: (v) => setState(() => _showOnlyWithinHour = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Show only within 1 hour of target'),
                    ),
                    CheckboxListTile(
                      value: _dontScoreOutside,
                      onChanged: (v) => setState(() => _dontScoreOutside = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Dont Score project if outside of hour range'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Session Duration',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
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
          ],
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
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: OutlinedButton(
                onPressed: value > min ? () => onChanged(value - step) : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.remove, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.withValues(alpha: 0.12),
              ),
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: OutlinedButton(
                onPressed: value < max ? () => onChanged(value + step) : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.add, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    final text =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.withValues(alpha: 0.12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _centerSelectedProjectCard(ProjectModel? project) async {
    if (!_projectPageController.hasClients) return;
    final targetPage = project == null
        ? 0
        : (_filteredProjects.indexWhere((p) => p.id == project.id) + 1);
    if (targetPage < 0) return;
    await _projectPageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _archiveSelectedProjectWithNearestFallback() async {
    final selected = _selectedProject;
    if (selected == null) return;
    final activeBefore = projects.where((p) => p.isActive).toList();
    final oldIndex = activeBefore.indexWhere((p) => p.id == selected.id);
    selected.archive();
    final remainingActive = projects
        .where((p) => p.isActive && p.id != selected.id)
        .toList();

    ProjectModel? fallback;
    if (remainingActive.isNotEmpty) {
      final clampedIndex = oldIndex.clamp(0, remainingActive.length - 1);
      fallback = remainingActive[clampedIndex];
    }

    setState(() {
      _selectedProject = fallback;
      _syncEditorFromSelectedProject();
    });
    await _loadProjects();
  }

  Future<void> _showProjectInfoModal(ProjectModel? project) async {
    if (!mounted) return;
    final title = project?.name ?? 'No Project';
    final description = project?.description ?? 'No description yet';
    final imagePath = project == null ? null : _projectImagePath(project);
    final milestones = project == null
        ? <String>[]
        : _projectMilestones(project);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            if (project != null)
              IconButton(
                tooltip: 'Edit project info',
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _showEditProjectInfoDialog(project);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imagePath),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('Unable to preview image'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(description),
              if (milestones.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Milestones',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ...milestones.map(
                  (milestone) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $milestone'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (project != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showProjectPhotoSheet(project);
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Photo'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProjectInfoDialog(ProjectModel project) async {
    final titleController = TextEditingController(text: project.name);
    final descriptionController = TextEditingController(
      text: project.description ?? '',
    );
    final milestonesController = TextEditingController(
      text: _projectMilestones(project).join('\n'),
    );
    String selectedIconName = project.iconName ?? 'folder';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Project Info'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Project Icon',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availableProjectIcons.map((iconName) {
                      final selected = selectedIconName == iconName;
                      return ChoiceChip(
                        label: Icon(_projectIconData(iconName), size: 18),
                        selected: selected,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedIconName = iconName;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: milestonesController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Milestones (one per line)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showProjectPhotoSheet(project);
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Photo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title cannot be empty')),
                  );
                  return;
                }
                final milestones = milestonesController.text
                    .split('\n')
                    .map((m) => m.trim())
                    .where((m) => m.isNotEmpty)
                    .toList();
                final currentImage = _projectImagePath(project);

                project.name = title;
                project.description = descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim();
                project.iconName = selectedIconName;
                project.notes = _composeProjectNotes(
                  imagePath: currentImage,
                  milestones: milestones,
                );
                await project.save();

                if (!mounted) return;
                setState(() {});
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProjectPhotoSheet(ProjectModel project) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Add from local album'),
                subtitle: const Text('Select image from gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickProjectPhotoFromGallery(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Upload image or GIF from files'),
                subtitle: Text(
                  'Accepted: ${_supportedVisualExtensions.join(', ')}',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickProjectPhotoFromFiles(project);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickProjectPhotoFromGallery(ProjectModel project) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    final sourcePath = picked?.path;
    if (sourcePath == null) return;
    await _setProjectPhotoFromPath(project, sourcePath);
  }

  Future<void> _pickProjectPhotoFromFiles(ProjectModel project) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedVisualExtensions,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return;
    await _setProjectPhotoFromPath(project, sourcePath);
  }

  Future<void> _setProjectPhotoFromPath(
    ProjectModel project,
    String sourcePath,
  ) async {
    final extension = _extensionOf(sourcePath).toLowerCase();
    if (!_supportedVisualExtensions.contains(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unsupported format .$extension. Allowed: ${_supportedVisualExtensions.join(', ')}',
          ),
        ),
      );
      return;
    }

    final copiedPath = await _copyToAppStorage(
      sourcePath,
      subFolder: 'project_visuals',
    );
    project.notes = _composeProjectNotes(
      imagePath: copiedPath,
      milestones: _projectMilestones(project),
    );
    await project.save();

    if (!mounted) return;
    setState(() {});
  }

  String? _projectImagePath(ProjectModel project) {
    final notes = project.notes;
    if (notes == null || notes.isEmpty) return null;
    final firstLine = notes.split('\n').first.trim();
    if (firstLine.startsWith('[photo]')) {
      final path = firstLine.substring('[photo]'.length).trim();
      return path.isEmpty ? null : path;
    }
    return null;
  }

  List<String> _projectMilestones(ProjectModel project) {
    final notes = project.notes;
    if (notes == null || notes.trim().isEmpty) {
      return project.tags;
    }
    final lines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return project.tags;
    if (lines.first.startsWith('[photo]')) {
      return lines.skip(1).toList();
    }
    return lines;
  }

  String? _composeProjectNotes({
    String? imagePath,
    required List<String> milestones,
  }) {
    final lines = <String>[];
    if (imagePath != null && imagePath.isNotEmpty) {
      lines.add('[photo]$imagePath');
    }
    lines.addAll(milestones);
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  String _extensionOf(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '';
    return path.substring(lastDot + 1);
  }

  Future<String> _copyToAppStorage(
    String sourcePath, {
    required String subFolder,
  }) async {
    final sourceFile = File(sourcePath);
    final extension = _extensionOf(sourcePath);
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/$subFolder');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetPath =
        '${targetDir.path}/${DateTime.now().millisecondsSinceEpoch}.${extension.isEmpty ? "bin" : extension}';
    final copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  static const List<String> _availableProjectIcons = [
    'folder',
    'work',
    'school',
    'fitness_center',
    'palette',
    'code',
    'music_note',
    'home',
    'business',
    'psychology',
    'science',
    'book',
    'camera',
  ];

  IconData _projectIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'music_note':
        return Icons.music_note;
      case 'home':
        return Icons.home;
      case 'business':
        return Icons.business;
      case 'psychology':
        return Icons.psychology;
      case 'science':
        return Icons.science;
      case 'book':
        return Icons.book;
      case 'camera':
        return Icons.camera_alt;
      default:
        return Icons.folder;
    }
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'e.g., Study for CFA',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await _createProject(name);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject(String name) async {
    try {
      print('Creating project with name: $name');

      final project = ProjectModel(
        id: 'project_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: null,
        color: '#607D8B',
        iconName: 'folder',
        priority: 1,
        targetType: 'daily',
        dailySessionTarget: 1,
        weeklySessionTarget: 2,
        preferredWorkHour: 9,
        activeDays: const [1, 2, 3, 4, 5, 6, 7],
        workDurationMinutes: 25,
        breakDurationMinutes: 5,
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
        _showArchived = false;
        _selectedProject = project;
        _syncEditorFromSelectedProject();
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
        return 'Morning';
      case 3:
        return 'Afternoon';
      case 4:
        return 'Evening';
      default:
        return 'Active';
    }
  }

  String? _daySummaryText(int day, int state) {
    final dayName = _getDayName(day);
    if (state == 1) return null; // Not active: do not show on summary text.
    if (state == 0) return dayName; // Fully active: show only weekday.
    return '$dayName, ${_dayStateLabel(state)}';
  }

  String _activeDaysSummaryText() {
    final entries = <String>[];
    for (int day = 1; day <= 7; day++) {
      final text = _daySummaryText(day, _dayStates[day] ?? 0);
      if (text != null) {
        entries.add(text);
      }
    }
    if (entries.isEmpty) return 'No active days';
    return entries.join(', ');
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

