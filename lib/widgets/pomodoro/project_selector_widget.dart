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

  const ProjectSelectorWidget({
    Key? key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
    this.isCollapsed = false,
    this.isRunning = false,
    this.canSubmitLog = false,
  }) : super(key: key);

  @override
  _ProjectSelectorWidgetState createState() => _ProjectSelectorWidgetState();
}

class _ProjectSelectorWidgetState extends State<ProjectSelectorWidget> {
  bool showAllProjects = false;

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

    // Determine which projects to show based on selection state and toggle
    List<ProjectModel> projectsToShow;
    if (widget.selectedProject != null && !showAllProjects) {
      // Show only selected project with expand option
      projectsToShow = activeProjects
          .where((p) => p.id == widget.selectedProject!.id)
          .toList();
    } else {
      projectsToShow = activeProjects;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show toggle button if a project is selected
          if (widget.selectedProject != null && !widget.isCollapsed) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  showAllProjects = !showAllProjects;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [SizedBox(width: 4)],
                ),
              ),
            ),
          ],
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
  }

  Widget _buildProjectChip(
    BuildContext context,
    ProjectModel project,
    bool isSelected,
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.iconName != null) ...[
              Icon(
                _getIconData(project.iconName!),
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
              SizedBox(width: 4),
            ],
            Text(
              project.shortName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
            if (!widget.isCollapsed) ...[
              SizedBox(width: 4),
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
                        : _getRemainingWorkText(project),
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

  String _getRemainingWorkText(ProjectModel project) {
    final remaining = project.getRemainingTodayPomodoros();
    if (remaining <= 0) {
      return 'Complete ✓';
    } else if (remaining == 1) {
      return '1 left';
    } else {
      return '$remaining left';
    }
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
    Key? key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
  }) : super(key: key);

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

    return Container(
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
                  color: isSelected ? color : color.withOpacity(0.1),
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
