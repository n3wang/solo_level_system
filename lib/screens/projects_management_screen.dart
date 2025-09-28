// lib/screens/projects_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/project_model.dart';

class ProjectsManagementScreen extends StatefulWidget {
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
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectDialog,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('New Project'),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.folder_open : Icons.archive,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              isActive ? 'No active projects' : 'No archived projects',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              SizedBox(height: 8),
              Text(
                'Create your first project to organize your pomodoro sessions!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ],
        ),
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

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showProjectDetails(project),
        onLongPress: () => _showProjectOptions(project, isActive),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (project.iconName != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconData(project.iconName!),
                        color: color,
                        size: 20,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          project.name[0].toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (project.description?.isNotEmpty == true) ...[
                          SizedBox(height: 4),
                          Text(
                            project.description!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isActive) Icon(Icons.archive, color: Colors.grey[500]),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(
                    'Sessions',
                    '${project.totalCompletedPomodoros}',
                    Icons.timer,
                  ),
                  SizedBox(width: 8),
                  _buildStatChip(
                    'Progress',
                    project.progressText,
                    Icons.trending_up,
                  ),
                  if (project.priority > 0) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(
                          project.priority,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPriorityText(project.priority),
                        style: TextStyle(
                          color: _getPriorityColor(project.priority),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (project.iconName != null)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _parseColor(project.color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getIconData(project.iconName!),
                        color: _parseColor(project.color),
                        size: 24,
                      ),
                    ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (project.description?.isNotEmpty == true)
                          Text(
                            project.description!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Total Sessions',
                        '${project.totalCompletedPomodoros}',
                      ),
                      _buildDetailRow('Progress', project.progressText),
                      _buildDetailRow(
                        'Created',
                        _formatDate(project.createdAt),
                      ),
                      _buildDetailRow(
                        'Priority',
                        _getPriorityText(project.priority),
                      ),
                      _buildDetailRow('Status', project.statusText),
                      if (project.tags.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          'Tags',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
              ),
            ],
          ),
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Project'),
            onTap: () {
              Navigator.pop(context);
              _editProject(project);
            },
          ),
          ListTile(
            leading: Icon(isActive ? Icons.archive : Icons.unarchive),
            title: Text(isActive ? 'Archive Project' : 'Restore Project'),
            onTap: () {
              Navigator.pop(context);
              if (isActive) {
                project.archive();
              } else {
                project.unarchive();
              }
              setState(() {});
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Project', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteProject(project);
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
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
      builder: (context) => AlertDialog(
        title: Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              project.delete();
              setState(() {
                projects.remove(project);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Project deleted')));
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
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
    int selectedDailyTarget = project?.dailySessionTarget ?? 2;
    int selectedWeeklyTarget = project?.weeklySessionTarget ?? 10;
    int? selectedWorkHour = project?.preferredWorkHour;
    List<int> selectedActiveDays = List.from(
      project?.activeDays ?? [1, 2, 3, 4, 5],
    );
    final dailyTargetController = TextEditingController(
      text: selectedDailyTarget.toString(),
    );
    final weeklyTargetController = TextEditingController(
      text: selectedWeeklyTarget.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Project' : 'Create New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g., "Learn Flutter"',
                  ),
                ),
                SizedBox(height: 16),
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
                  value: selectedPriority,
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
                // Target Type Selection
                DropdownButtonFormField<String>(
                  value: selectedTargetType,
                  decoration: InputDecoration(labelText: 'Target Type'),
                  items: [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily Target'),
                    ),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Weekly Target'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedTargetType = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                // Session Target Input
                if (selectedTargetType == 'daily')
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Daily Session Target',
                      hintText: 'Number of sessions per day',
                    ),
                    keyboardType: TextInputType.number,
                    controller: dailyTargetController,
                    onChanged: (value) {
                      selectedDailyTarget =
                          int.tryParse(value) ?? selectedDailyTarget;
                    },
                  ),
                if (selectedTargetType == 'weekly')
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Weekly Session Target',
                      hintText: 'Number of sessions per week',
                    ),
                    keyboardType: TextInputType.number,
                    controller: weeklyTargetController,
                    onChanged: (value) {
                      selectedWeeklyTarget =
                          int.tryParse(value) ?? selectedWeeklyTarget;
                    },
                  ),
                SizedBox(height: 16),
                // Active Days Selection
                Text(
                  'Active Days:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                SizedBox(height: 16),
                // Preferred Work Hour
                DropdownButtonFormField<int?>(
                  dropdownColor: Theme.of(context).canvasColor,
                  value: selectedWorkHour,
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
