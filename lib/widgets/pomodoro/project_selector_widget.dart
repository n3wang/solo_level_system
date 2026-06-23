// lib/widgets/pomodoro/project_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:solo_level_system/models/project_model.dart';

class ProjectSelectorWidget extends StatefulWidget {
  final List<ProjectModel> projects;
  final ProjectModel? selectedProject;
  final Function(ProjectModel?) onProjectSelected;
  final bool isCollapsed;
  final bool isRunning;
  final bool canSubmitLog;
  final double? selectedExpandedWidth;

  const ProjectSelectorWidget({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
    this.isCollapsed = false,
    this.isRunning = false,
    this.canSubmitLog = false,
    this.selectedExpandedWidth,
  });

  @override
  _ProjectSelectorWidgetState createState() => _ProjectSelectorWidgetState();
}

class _ProjectSelectorWidgetState extends State<ProjectSelectorWidget> {
  Color _chipBackgroundColor({
    required BuildContext context,
    required Color accent,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (selected) {
      return Color.lerp(scheme.surface, accent, 0.18)!.withValues(alpha: 0.9);
    }
    return scheme.surface.withValues(alpha: 0.82);
  }

  Color _chipBorderColor({
    required BuildContext context,
    required Color accent,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (selected) return accent.withValues(alpha: 0.9);
    return scheme.onSurface.withValues(alpha: 0.36);
  }

  Color _chipPrimaryTextColor({
    required BuildContext context,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return selected
        ? scheme.onSurface.withValues(alpha: 0.96)
        : scheme.onSurface.withValues(alpha: 0.88);
  }

  Color _chipSecondaryTextColor({
    required BuildContext context,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return selected
        ? scheme.onSurface.withValues(alpha: 0.78)
        : scheme.onSurface.withValues(alpha: 0.66);
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 420;
    final now = DateTime.now();
    final visibleProjects = <_ProjectChipPresentation>[];
    for (final project in widget.projects.where((p) => p.isActive)) {
      final presentation = _presentationForProject(project, now);
      if (presentation != null) {
        visibleProjects.add(presentation);
      }
      if (visibleProjects.length >= 6) break;
    }

    if (visibleProjects.isEmpty) {
      return SizedBox.shrink();
    }

    // Hide completely during active work sessions (not during breaks or submission)
    if (widget.isRunning && !widget.canSubmitLog) {
      return SizedBox.shrink();
    }

    // Show only selected project; unselecting returns to all projects.
    final projectsToShow = widget.selectedProject != null
        ? visibleProjects
            .where((entry) => entry.project.id == widget.selectedProject!.id)
            .toList()
        : visibleProjects;
    final showSingleSelectedChip =
        widget.selectedProject != null && projectsToShow.length == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: showSingleSelectedChip ? 0 : 8,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSingleSelectedChip)
                _buildAnimatedSingleSelectedChip(
                  context,
                  projectsToShow.first.project,
                  projectsToShow.first.opacity,
                  constraints.maxWidth,
                  compact,
                )
              else
                Wrap(
                  spacing: 8,
                  children: projectsToShow.map((entry) {
                    final isSelected =
                        widget.selectedProject?.id == entry.project.id;
                    return _buildProjectChip(
                      context,
                      entry.project,
                      isSelected,
                      compact: compact,
                      opacity: entry.opacity,
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSingleSelectedChip(
    BuildContext context,
    ProjectModel project,
    double baseOpacity,
    double maxWidth,
    bool compact,
  ) {
    final baseColor = _parseColor(project.color);
    final borderColor =
        _chipBorderColor(context: context, accent: baseColor, selected: true);
    final foregroundColor = _chipPrimaryTextColor(context: context, selected: true);
    final secondaryColor =
        _chipSecondaryTextColor(context: context, selected: true);
    final tertiaryColor =
        _chipSecondaryTextColor(context: context, selected: false);
    final targetWidth = widget.selectedExpandedWidth == null
        ? maxWidth
        : widget.selectedExpandedWidth!.clamp(0.0, maxWidth);
    return TweenAnimationBuilder<double>(
      key: ValueKey('selected-${project.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final expandProgress = (t / 0.72).clamp(0.0, 1.0);
        final width = (targetWidth * (0.58 + (0.42 * expandProgress)));
        final chipColor = _chipBackgroundColor(
          context: context,
          accent: baseColor,
          selected: true,
        );
        const borderWidth = 1.2;

        return SizedBox(
          width: width,
          child: Opacity(
            opacity: baseOpacity,
            child: GestureDetector(
              onTap: () => widget.onProjectSelected(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  border: Border.all(color: borderColor, width: borderWidth),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                  if (project.iconName != null) ...[
                    Icon(
                      _getIconData(project.iconName!),
                      size: compact ? 13 : 14,
                      color: baseColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: foregroundColor,
                      ),
                    ),
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          project.progressText,
                          style: TextStyle(
                            fontSize: compact ? 9 : 10,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          '${project.workDurationMinutes}-${project.breakDurationMinutes}',
                          style: TextStyle(
                            fontSize: compact ? 8 : 9,
                            color: tertiaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectChip(
    BuildContext context,
    ProjectModel project,
    bool isSelected,
    {bool expandToFullWidth = false, bool compact = false, double opacity = 1.0}
  ) {
    final color = _parseColor(project.color);
    final chipColor = _chipBackgroundColor(
      context: context,
      accent: color,
      selected: isSelected,
    );
    final borderColor = _chipBorderColor(
      context: context,
      accent: color,
      selected: isSelected,
    );
    final primaryTextColor =
        _chipPrimaryTextColor(context: context, selected: isSelected);
    final secondaryTextColor =
        _chipSecondaryTextColor(context: context, selected: isSelected);

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          // Untoggle - show all projects
          widget.onProjectSelected(null);
        } else {
          // Select this project
          widget.onProjectSelected(project);
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: expandToFullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: chipColor,
            border: Border.all(color: borderColor, width: isSelected ? 1.7 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: expandToFullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
            if (project.iconName != null) ...[
              Icon(
                _getIconData(project.iconName!),
                size: compact ? 13 : 14,
                color: color,
              ),
              SizedBox(width: 4),
            ],
            if (expandToFullWidth)
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    color: primaryTextColor,
                  ),
                ),
              )
            else
              Text(
                isSelected ? project.name : project.initials,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  letterSpacing: isSelected ? 0 : 0.4,
                ),
              ),
            if (!widget.isCollapsed) ...[
              SizedBox(width: 4),
              if (expandToFullWidth) ...[
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      project.progressText,
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        color: secondaryTextColor,
                      ),
                    ),
                    Text(
                      '${project.workDurationMinutes}-${project.breakDurationMinutes}',
                      style: TextStyle(
                        fontSize: compact ? 8 : 9,
                        color: secondaryTextColor.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ] else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.progressText,
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        color: secondaryTextColor,
                      ),
                    ),
                    Text(
                      '${project.workDurationMinutes}-${project.breakDurationMinutes}',
                      style: TextStyle(
                        fontSize: compact ? 8 : 9,
                        color: secondaryTextColor.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  _ProjectChipPresentation? _presentationForProject(
    ProjectModel project,
    DateTime now,
  ) {
    final meta = _projectMeta(project);
    final showOnlyWithinHour = _boolMeta(meta['show_only_within_hour']);

    if (!showOnlyWithinHour) {
      return _ProjectChipPresentation(project: project, opacity: 1);
    }

    final withinWindow = _isWithinBufferedWindow(
      now: now,
      project: project,
      morningStart: _timeMeta(
            meta['morning_start'],
          ) ??
          TimeOfDay(hour: project.preferredWorkHour ?? 9, minute: 0),
      afternoonStart:
          _timeMeta(meta['afternoon_start']) ??
          const TimeOfDay(hour: 13, minute: 0),
      eveningStart:
          _timeMeta(meta['evening_start']) ??
          const TimeOfDay(hour: 18, minute: 30),
      dayStates: _dayStatesMeta(meta['day_states'], fallbackActiveDays: project.activeDays),
    );

    return _ProjectChipPresentation(
      project: project,
      opacity: withinWindow ? 1.0 : 0.45,
    );
  }

  Map<String, String> _projectMeta(ProjectModel project) {
    final notes = project.notes;
    if (notes == null || notes.trim().isEmpty) return const {};
    final meta = <String, String>{};
    for (final raw in notes.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('[meta]')) continue;
      final payload = line.substring('[meta]'.length);
      final idx = payload.indexOf('=');
      if (idx <= 0 || idx >= payload.length - 1) continue;
      final key = payload.substring(0, idx).trim();
      final value = payload.substring(idx + 1).trim();
      if (key.isNotEmpty) meta[key] = value;
    }
    return meta;
  }

  bool _boolMeta(String? raw) => raw?.toLowerCase() == 'true';

  TimeOfDay? _timeMeta(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Map<int, int> _dayStatesMeta(String? raw, {required List<int> fallbackActiveDays}) {
    if (raw != null && raw.trim().isNotEmpty) {
      final parts = raw.split(',');
      if (parts.length == 7) {
        final map = <int, int>{};
        bool allValid = true;
        for (int day = 1; day <= 7; day++) {
          final parsed = int.tryParse(parts[day - 1].trim());
          if (parsed == null || parsed < 0 || parsed > 4) {
            allValid = false;
            break;
          }
          map[day] = parsed;
        }
        if (allValid) return map;
      }
    }
    return {for (int day = 1; day <= 7; day++) day: fallbackActiveDays.contains(day) ? 0 : 1};
  }

  bool _isWithinBufferedWindow({
    required DateTime now,
    required ProjectModel project,
    required TimeOfDay morningStart,
    required TimeOfDay afternoonStart,
    required TimeOfDay eveningStart,
    required Map<int, int> dayStates,
  }) {
    if (!project.isActive) return false;
    final state = dayStates[now.weekday] ?? 1;
    if (state == 1) return false;

    int toMinute(TimeOfDay time) => time.hour * 60 + time.minute;
    final nowMinute = now.hour * 60 + now.minute;
    final morning = toMinute(morningStart);
    final afternoon = toMinute(afternoonStart);
    final evening = toMinute(eveningStart);

    int start;
    int end;
    switch (state) {
      case 2: // morning
        start = morning;
        end = afternoon;
        break;
      case 3: // afternoon
        start = afternoon;
        end = evening;
        break;
      case 4: // evening
        start = evening;
        end = 24 * 60;
        break;
      case 0: // fully active
      default:
        start = morning;
        end = 24 * 60;
        break;
    }

    final bufferedStart = (start - 60).clamp(0, 24 * 60);
    final bufferedEnd = (end + 60).clamp(0, 24 * 60);
    return nowMinute >= bufferedStart && nowMinute <= bufferedEnd;
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue; // Default fallback
    }
  }

  IconData _getIconData(String iconName) {
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
}

class _ProjectChipPresentation {
  final ProjectModel project;
  final double opacity;

  const _ProjectChipPresentation({required this.project, required this.opacity});
}

// Compact version for when space is limited
class CompactProjectSelectorWidget extends StatelessWidget {
  final List<ProjectModel> projects;
  final ProjectModel? selectedProject;
  final Function(ProjectModel?) onProjectSelected;

  const CompactProjectSelectorWidget({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final activeProjects = projects
        .where((p) => p.isActiveToday)
        .take(6)
        .toList();

    if (activeProjects.isEmpty) {
      return SizedBox.shrink();
    }

    // If a project is selected, show only that project
    final projectsToShow = selectedProject != null
        ? activeProjects.where((p) => p.id == selectedProject!.id).toList()
        : activeProjects;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: projectsToShow.length,
        itemBuilder: (context, index) {
          final project = projectsToShow[index];
          final isSelected = selectedProject?.id == project.id;
          final color = _parseColor(project.color);

          return Padding(
            padding: EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                if (isSelected) {
                  onProjectSelected(null);
                } else {
                  onProjectSelected(project);
                }
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.1),
                  border: Border.all(color: color, width: isSelected ? 2 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: project.iconName != null
                      ? Icon(
                          _getIconData(project.iconName!),
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        )
                      : Text(
                          project.initials,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconName) {
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
      default:
        return Icons.folder;
    }
  }
}
