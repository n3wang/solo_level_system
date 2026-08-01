// lib/screens/projects_management_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/utils/unlock_service.dart';
import 'package:solo_level_system/utils/dev_data.dart';
import 'package:solo_level_system/widgets/common/index.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

class ProjectsManagementScreen extends StatefulWidget {
  final String? initialSelectedProjectId;

  const ProjectsManagementScreen({super.key, this.initialSelectedProjectId});

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
      projects = box.values
          .where((p) => DevData.keepVisible(id: p.id))
          .toList();

      print('Loaded ${projects.length} projects');
      for (var project in projects) {
        print('Project: ${project.name}');
      }

      setState(() {
        final filtered = _filteredProjects;
        if (_selectedProject == null &&
            widget.initialSelectedProjectId != null) {
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
            OnOffToggle(
              value: !_showArchived,
              onLabel: 'Active Project',
              offLabel: 'Archived Project',
              onIcon: Icons.folder_open,
              offIcon: Icons.archive,
              onChanged: (active) {
                setState(() {
                  _showArchived = !active;
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

  int get _selectedProjectSegmentIndex {
    if (_selectedProject == null) return 0;
    final i = _filteredProjects.indexWhere((p) => p.id == _selectedProject!.id);
    return i < 0 ? 0 : i + 1;
  }

  bool get _canRandomProjectRoll => _filteredProjects.length > 1;

  void _syncEditorFromSelectedProject() {
    final p = _selectedProject;
    if (p == null) {
      _dailyTarget = 1;
      _weeklyTarget = 2;
      _workDuration = 25;
      _breakDuration = 5;
      _morningStart = const TimeOfDay(hour: 9, minute: 0);
      _afternoonStart = const TimeOfDay(hour: 13, minute: 0);
      _eveningStart = const TimeOfDay(hour: 18, minute: 30);
      _sendNotification = false;
      _showOnlyWithinHour = false;
      _dontScoreOutside = false;
      for (int day = 1; day <= 7; day++) {
        _dayStates[day] = 0;
      }
      return;
    }
    _dailyTarget = p.dailySessionTarget;
    _weeklyTarget = p.weeklySessionTarget;
    _workDuration = p.workDurationMinutes;
    _breakDuration = p.breakDurationMinutes;
    final meta = _projectMeta(project: p);
    final preferred = p.preferredWorkHour ?? 9;
    _morningStart =
        _timeFromMeta(meta['morning_start']) ??
        TimeOfDay(hour: preferred, minute: 0);
    _afternoonStart =
        _timeFromMeta(meta['afternoon_start']) ??
        const TimeOfDay(hour: 13, minute: 0);
    _eveningStart =
        _timeFromMeta(meta['evening_start']) ??
        const TimeOfDay(hour: 18, minute: 30);
    _sendNotification = _boolFromMeta(meta['send_notification']);
    _showOnlyWithinHour = _boolFromMeta(meta['show_only_within_hour']);
    _dontScoreOutside = _boolFromMeta(meta['dont_score_outside']);
    final parsedDayStates = _dayStatesFromMeta(meta['day_states']);
    for (int day = 1; day <= 7; day++) {
      if (parsedDayStates != null) {
        _dayStates[day] = parsedDayStates[day] ?? 0;
      } else {
        _dayStates[day] = p.activeDays.contains(day) ? 0 : 1;
      }
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
    p.notes = _composeProjectNotes(
      imagePath: _projectImagePath(p),
      milestones: _projectMilestones(p),
      metadata: _projectMetaForPersistence(),
    );
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

    return SizedBox(
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
                                      color: AppColorPalette.textMuted,
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
                      LabeledSegmentBar(
                        label: 'Project',
                        bar: SegmentBar(
                          count: _filteredProjects.length + 1,
                          selectedIndex: _selectedProjectSegmentIndex,
                          onSelected: (index) {
                            final project = index == 0
                                ? null
                                : _filteredProjects[index - 1];
                            setState(() {
                              _selectedProject = project;
                              _syncEditorFromSelectedProject();
                            });
                          },
                        ),
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
            SizedBox(
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
            const SizedBox(height: 16),
            SizedBox(
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
            SizedBox(
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
                    LabeledSegmentBar(
                      label: 'Active Days',
                      bar: SegmentBar(
                        count: 7,
                        segmentStates: [
                          for (int day = 1; day <= 7; day++)
                            _dayStates[day] ?? 0,
                        ],
                        partialBandCount: 3,
                        segmentWidth: 20,
                        segmentHeight: 36,
                        spacing: 8,
                        borderWidth: AppUiSizes.mediumBorderWidth,
                        borderRadius: 4,
                        onSelected: (index) async {
                          final day = index + 1;
                          setState(() {
                            _dayStates[day] = _nextDayState(
                              _dayStates[day] ?? 0,
                            );
                          });
                          await _persistSelectedProject();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeDaysSummaryText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColorPalette.textMuted,
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
                          child: _buildTimeField('Morning', _morningStart, (
                            v,
                          ) async {
                            setState(() => _morningStart = v);
                            await _persistSelectedProject();
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField('Afternoon', _afternoonStart, (
                            v,
                          ) async {
                            setState(() => _afternoonStart = v);
                            await _persistSelectedProject();
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField('Evening', _eveningStart, (
                            v,
                          ) async {
                            setState(() => _eveningStart = v);
                            await _persistSelectedProject();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OnOffToggleListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Create Notification'),
                      value: _sendNotification,
                      onChanged: (v) async {
                        setState(() => _sendNotification = v);
                        await _persistSelectedProject();
                      },
                    ),
                    OnOffToggleListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show only within 1 hour of target'),
                      value: _showOnlyWithinHour,
                      onChanged: (v) async {
                        setState(() => _showOnlyWithinHour = v);
                        await _persistSelectedProject();
                      },
                    ),
                    OnOffToggleListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Dont Score project if outside of hour range',
                      ),
                      value: _dontScoreOutside,
                      onChanged: (v) async {
                        setState(() => _dontScoreOutside = v);
                        await _persistSelectedProject();
                      },
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
        Text(label, style: Theme.of(context).textTheme.labelLarge),
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
                  showAppSnack(context, text: 'Title cannot be empty');
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
                  metadata: _projectMeta(project: project),
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
      showAppSnack(
        context,
        text:
            'Unsupported format .$extension. Allowed: ${_supportedVisualExtensions.join(', ')}',
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
      metadata: _projectMeta(project: project),
    );
    await project.save();

    if (!mounted) return;
    setState(() {});
  }

  String? _projectImagePath(ProjectModel project) {
    final notes = project.notes;
    if (notes == null || notes.isEmpty) return null;
    for (final raw in notes.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('[photo]')) {
        final path = line.substring('[photo]'.length).trim();
        return path.isEmpty ? null : path;
      }
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
    return lines
        .where((line) => !line.startsWith('[photo]'))
        .where((line) => !line.startsWith('[meta]'))
        .toList();
  }

  Map<String, String> _projectMeta({required ProjectModel project}) {
    final notes = project.notes;
    if (notes == null || notes.trim().isEmpty) return const {};
    final meta = <String, String>{};
    for (final raw in notes.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('[meta]')) continue;
      final payload = line.substring('[meta]'.length);
      final index = payload.indexOf('=');
      if (index <= 0 || index >= payload.length - 1) continue;
      final key = payload.substring(0, index).trim();
      final value = payload.substring(index + 1).trim();
      if (key.isNotEmpty) meta[key] = value;
    }
    return meta;
  }

  bool _boolFromMeta(String? raw) => raw?.toLowerCase() == 'true';

  TimeOfDay? _timeFromMeta(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeToMeta(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Map<int, int>? _dayStatesFromMeta(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final values = raw.split(',');
    if (values.length != 7) return null;
    final map = <int, int>{};
    for (int day = 1; day <= 7; day++) {
      final parsed = int.tryParse(values[day - 1].trim());
      if (parsed == null || parsed < 0 || parsed > 4) return null;
      map[day] = parsed;
    }
    return map;
  }

  String _dayStatesToMeta() => List.generate(
    7,
    (index) => (_dayStates[index + 1] ?? 0).toString(),
  ).join(',');

  Map<String, String> _projectMetaForPersistence() {
    return {
      'morning_start': _timeToMeta(_morningStart),
      'afternoon_start': _timeToMeta(_afternoonStart),
      'evening_start': _timeToMeta(_eveningStart),
      'day_states': _dayStatesToMeta(),
      'send_notification': _sendNotification.toString(),
      'show_only_within_hour': _showOnlyWithinHour.toString(),
      'dont_score_outside': _dontScoreOutside.toString(),
    };
  }

  String? _composeProjectNotes({
    String? imagePath,
    required List<String> milestones,
    Map<String, String>? metadata,
  }) {
    final lines = <String>[];
    if (imagePath != null && imagePath.isNotEmpty) {
      lines.add('[photo]$imagePath');
    }
    if (metadata != null && metadata.isNotEmpty) {
      final orderedKeys = metadata.keys.toList()..sort();
      for (final key in orderedKeys) {
        final value = metadata[key];
        if (value == null || value.trim().isEmpty) continue;
        lines.add('[meta]$key=$value');
      }
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
    // Enforce project-slot capacity from `option` cards. When no option cards
    // exist yet (max <= 0), the catalog hasn't seeded them, so we don't gate.
    final maxProjects = UnlockService.capacityFor(
      SettingKeys.projectSlots,
      base: 0,
    );
    if (maxProjects > 0 && projects.length >= maxProjects) {
      showAppSnack(
        context,
        text:
            'Project limit reached ($maxProjects). Unlock more Project Slot cards in Motivation.',
      );
      return;
    }

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

      showAppSnack(context, text: '🎉 Project created!');
    } catch (e) {
      print('Error creating project: $e');
      showAppSnack(context, text: 'Error creating project: $e');
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
}
