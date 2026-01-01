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

class _ProjectsManagementScreenState extends State<ProjectsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProjectModel> projects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.folder), text: 'Active'),
            Tab(icon: Icon(Icons.archive), text: 'Archived'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveProjectsTab(), _buildArchivedProjectsTab()],
      ),
      floatingActionButton: CustomFloatingActionButton(
        label: 'New Project',
        icon: Icons.add,
        onPressed: _showCreateProjectDialog,
      ),
    );
  }

  Widget _buildActiveProjectsTab() {
    final activeProjects = projects.where((p) => p.isActive).toList();
    return _buildProjectsList(activeProjects, true);
  }

  Widget _buildArchivedProjectsTab() {
    final archivedProjects = projects.where((p) => !p.isActive).toList();
    return _buildProjectsList(archivedProjects, false);
  }

  Widget _buildProjectsList(List<ProjectModel> projectList, bool isActive) {
    if (projectList.isEmpty) {
      return EmptyState(
        icon: isActive ? Icons.folder_open : Icons.archive,
        title: isActive ? 'No active projects' : 'No archived projects',
        subtitle: isActive
            ? 'Create your first project to organize your pomodoro sessions!'
            : null,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: projectList.length,
      itemBuilder: (context, index) {
        final project = projectList[index];
        return _buildProjectCard(project, isActive);
      },
    );
  }

  Widget _buildProjectCard(ProjectModel project, bool isActive) {
    final color = _parseColor(project.color);

    return BaseCard(
      onTap: () => _showProjectDetails(project),
      onLongPress: () => _showProjectOptions(project, isActive),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: project.name,
            description: project.description,
            color: color,
            iconName: project.iconName,
            trailing: !isActive
                ? Icon(Icons.archive, color: Colors.grey[500])
                : null,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              StatChip(
                label: 'Sessions',
                value: '${project.totalCompletedPomodoros}',
                icon: Icons.timer,
              ),
              SizedBox(width: 8),
              StatChip(
                label: 'Progress',
                value: project.progressText,
                icon: Icons.trending_up,
              ),
              if (project.priority > 0) ...[
                SizedBox(width: 8),
                PriorityChip(priority: project.priority),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showProjectDetails(ProjectModel project) {
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
            CardHeader(
              title: project.name,
              description: project.description,
              color: _parseColor(project.color),
              iconName: project.iconName,
            ),
            SizedBox(height: 20),
            _buildDetailRow(
              'Total Sessions',
              '${project.totalCompletedPomodoros}',
            ),
            _buildDetailRow('Progress', project.progressText),
            _buildDetailRow('Created', _formatDate(project.createdAt)),
            _buildDetailRow('Priority', _getPriorityText(project.priority)),
            _buildDetailRow('Status', project.statusText),
            if (project.tags.isNotEmpty) ...[
              SizedBox(height: 16),
              Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: project.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showProjectOptions(ProjectModel project, bool isActive) {
    showModalBottomSheet(
      context: context,
      builder: (context) => OptionsBottomSheet(
        options: [
          BottomSheetOption(
            title: 'Edit Project',
            icon: Icons.edit,
            onTap: () => _editProject(project),
          ),
          BottomSheetOption(
            title: isActive ? 'Archive Project' : 'Restore Project',
            icon: isActive ? Icons.archive : Icons.unarchive,
            onTap: () {
              if (isActive) {
                project.archive();
              } else {
                project.unarchive();
              }
              setState(() {});
            },
          ),
          BottomSheetOption(
            title: 'Delete Project',
            icon: Icons.delete,
            onTap: () => _deleteProject(project),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _editProject(ProjectModel project) {
    _showProjectDialog(project: project);
  }

  void _deleteProject(ProjectModel project) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Project',
        message:
            'Are you sure you want to delete "${project.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          project.delete();
          setState(() {
            projects.remove(project);
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Project deleted')));
        },
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
    int selectedDailyTarget = project?.dailySessionTarget ?? 2;
    int selectedWeeklyTarget = project?.weeklySessionTarget ?? 10;
    int? selectedWorkHour = project?.preferredWorkHour;
    List<int> selectedActiveDays = List.from(
      project?.activeDays ?? [1, 2, 3, 4, 5, 6, 7],
    );
    final dailyTargetController = TextEditingController(
      text: selectedDailyTarget.toString(),
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
                    Text(
                      'Daily Session Target',
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
                                dailyTargetController.text = selectedDailyTarget
                                    .toString();
                              }
                            });
                          },
                          icon: Icon(Icons.remove_circle_outline),
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: dailyTargetController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                                dailyTargetController.text = selectedDailyTarget
                                    .toString();
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
                SizedBox(height: 20),

                // Active Days - Third most important
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
                    Wrap(
                      spacing: 8,
                      children: [
                        for (int day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(_getDayName(day)),
                            selected: selectedActiveDays.contains(day),
                            selectedColor: Colors.green.withOpacity(0.6),
                            checkmarkColor: Theme.of(context).primaryColor,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedActiveDays.add(day);
                                } else {
                                  selectedActiveDays.remove(day);
                                }
                              });
                            },
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
                              if (selectedBreakDuration > 1) {
                                selectedBreakDuration -= 1;
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
                              if (selectedBreakDuration < 30) {
                                selectedBreakDuration += 1;
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

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Urgent';
      default:
        return 'None';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
}
