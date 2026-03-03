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
  @override
  Widget build(BuildContext context) {
    final activeProjects = widget.projects
        .where((p) => p.isActiveToday)
        .take(6)
        .toList();

    if (activeProjects.isEmpty) {
      return SizedBox.shrink();
    }

    // Hide completely during active work sessions (not during breaks or submission)
    if (widget.isRunning && !widget.canSubmitLog) {
      return SizedBox.shrink();
    }

    // Show only selected project; unselecting returns to all projects.
    final projectsToShow = widget.selectedProject != null
        ? activeProjects.where((p) => p.id == widget.selectedProject!.id).toList()
        : activeProjects;
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
                  projectsToShow.first,
                  constraints.maxWidth,
                )
              else
                Wrap(
                  spacing: 8,
                  children: projectsToShow.map((project) {
                    final isSelected = widget.selectedProject?.id == project.id;
                    return _buildProjectChip(context, project, isSelected);
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
    double maxWidth,
  ) {
    final baseColor = _parseColor(project.color);
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
        final colorProgress = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
        final width = (targetWidth * (0.58 + (0.42 * expandProgress)));
        final chipColor = Color.lerp(
          baseColor.withValues(alpha: 0.1),
          baseColor,
          colorProgress,
        )!;
        final borderWidth = 1 + colorProgress;
        final foregroundColor = Color.lerp(
          baseColor,
          Colors.white,
          colorProgress,
        )!;
        final secondaryColor = Color.lerp(
          Colors.grey[600],
          Colors.white70,
          colorProgress,
        )!;
        final tertiaryColor = Color.lerp(
          Colors.grey[500],
          Colors.white60,
          colorProgress,
        )!;

        return SizedBox(
          width: width,
          child: GestureDetector(
            onTap: () => widget.onProjectSelected(null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                border: Border.all(color: baseColor, width: borderWidth),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (project.iconName != null) ...[
                    Icon(
                      _getIconData(project.iconName!),
                      size: 14,
                      color: foregroundColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                            fontSize: 10,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          widget.isRunning || widget.canSubmitLog
                              ? '${project.workDurationMinutes}/${project.breakDurationMinutes}m'
                              : project.progressText,
                          style: TextStyle(
                            fontSize: 9,
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
        );
      },
    );
  }

  Widget _buildProjectChip(
    BuildContext context,
    ProjectModel project,
    bool isSelected,
    {bool expandToFullWidth = false}
  ) {
    final color = _parseColor(project.color);

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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: expandToFullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: expandToFullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (project.iconName != null) ...[
              Icon(
                _getIconData(project.iconName!),
                size: 14,
                color: isSelected ? Colors.white : color,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              )
            else
              Text(
                project.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : color,
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
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    // Show remaining work when not running, or duration when running
                    Text(
                      widget.isRunning || widget.canSubmitLog
                          ? '${project.workDurationMinutes}/${project.breakDurationMinutes}m'
                          : project.progressText,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? Colors.white60 : Colors.grey[500],
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
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    // Show remaining work when not running, or duration when running
                    Text(
                      widget.isRunning || widget.canSubmitLog
                          ? '${project.workDurationMinutes}/${project.breakDurationMinutes}m'
                          : project.progressText,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? Colors.white60 : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
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
                          project.name[0].toUpperCase(),
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
