// lib/screens/audio_management_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/widgets/enhanced_audio_player.dart';
import 'package:solo_level_system/widgets/enhanced_audio_recorder.dart';

class AudioManagementScreen extends StatefulWidget {
  const AudioManagementScreen({super.key});

  @override
  _AudioManagementScreenState createState() => _AudioManagementScreenState();
}

class _AudioManagementScreenState extends State<AudioManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'Recent';
  bool _showFavoritesOnly = false;
  bool _showArchivedOnly = false;

  final List<String> _categories = [
    'All',
    'voice_note',
    'music',
    'meeting',
    'ambient',
    'Other',
  ];

  final List<String> _sortOptions = [
    'Recent',
    'Oldest',
    'Name A-Z',
    'Name Z-A',
    'Duration',
    'Size',
    'Most Played',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.library_music), text: 'Library'),
            Tab(icon: Icon(Icons.mic), text: 'Record'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: _showSearchDialog),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'sort', child: Text('Sort & Filter')),
              PopupMenuItem(value: 'export', child: Text('Export All')),
              PopupMenuItem(value: 'cleanup', child: Text('Cleanup Storage')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLibraryTab(), _buildRecordTab(), _buildAnalyticsTab()],
      ),
    );
  }

  Widget _buildLibraryTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: Hive.box<EnhancedAudioModel>(
              'audioFiles',
            ).listenable(),
            builder: (context, Box<EnhancedAudioModel> box, _) {
              final allAudios = box.values.toList();
              final filteredAudios = _filterAndSortAudios(allAudios);

              if (filteredAudios.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView.builder(
                  itemCount: filteredAudios.length,
                  itemBuilder: (context, index) {
                    final audio = filteredAudios[index];
                    return _buildAudioTile(audio);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          EnhancedAudioRecorder(
            onRecordingComplete: (audioModel) {
              // Audio saved automatically in the recorder
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Recording saved to library!'),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      _tabController.animateTo(0); // Switch to library tab
                    },
                  ),
                ),
              );
            },
            category: 'voice_note',
          ),
          SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<EnhancedAudioModel>('audioFiles').listenable(),
      builder: (context, Box<EnhancedAudioModel> box, _) {
        final allAudios = box.values.toList();
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(allAudios),
              SizedBox(height: 24),
              _buildCategoryChart(allAudios),
              SizedBox(height: 24),
              _buildUsageChart(allAudios),
              SizedBox(height: 24),
              _buildTopFiles(allAudios),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.replaceAll('_', ' ').titleCase),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
          ),
          SizedBox(width: 16),
          FilterChip(
            label: Text('Favorites'),
            selected: _showFavoritesOnly,
            onSelected: (selected) {
              setState(() => _showFavoritesOnly = selected);
            },
          ),
          SizedBox(width: 8),
          FilterChip(
            label: Text('Archived'),
            selected: _showArchivedOnly,
            onSelected: (selected) {
              setState(() => _showArchivedOnly = selected);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTile(EnhancedAudioModel audio) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(audio.category),
          child: Icon(_getCategoryIcon(audio.category), color: Colors.white),
        ),
        title: Text(
          audio.title ?? audio.fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${audio.durationFormatted} • ${audio.fileSizeFormatted}'),
            Text(
              DateFormat.yMMMd().add_jm().format(audio.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (audio.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: audio.tags
                    .take(3)
                    .map(
                      (tag) => Chip(
                        label: Text(tag, style: TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (audio.isFavorite)
              Icon(Icons.favorite, color: Colors.red, size: 16),
            if (audio.isArchived)
              Icon(Icons.archive, color: Colors.grey, size: 16),
            if (audio.playCount > 0)
              Text('${audio.playCount}', style: TextStyle(fontSize: 12)),
            Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                EnhancedAudioPlayer(
                  audioModel: audio,
                  onDelete: () => _deleteAudio(audio),
                  onEdit: (model) => _editAudio(model),
                ),
                SizedBox(height: 16),
                _buildAudioActions(audio),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioActions(EnhancedAudioModel audio) {
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(
          label: Text('Edit'),
          avatar: Icon(Icons.edit, size: 16),
          onPressed: () => _editAudio(audio),
        ),
        ActionChip(
          label: Text('Share'),
          avatar: Icon(Icons.share, size: 16),
          onPressed: () => _shareAudio(audio),
        ),
        ActionChip(
          label: Text('Export'),
          avatar: Icon(Icons.download, size: 16),
          onPressed: () => _exportAudio(audio),
        ),
        ActionChip(
          label: Text(audio.isArchived ? 'Unarchive' : 'Archive'),
          avatar: Icon(
            audio.isArchived ? Icons.unarchive : Icons.archive,
            size: 16,
          ),
          onPressed: () => _toggleArchive(audio),
        ),
        ActionChip(
          label: Text('Delete'),
          avatar: Icon(Icons.delete, size: 16),
          onPressed: () => _deleteAudio(audio),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No audio files found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Start recording to create your first audio file',
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _tabController.animateTo(1),
            child: Text('Start Recording'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text('Voice Note'),
                  avatar: Icon(Icons.mic, size: 16),
                  onPressed: () => _quickRecord('voice_note'),
                ),
                ActionChip(
                  label: Text('Meeting'),
                  avatar: Icon(Icons.meeting_room, size: 16),
                  onPressed: () => _quickRecord('meeting'),
                ),
                ActionChip(
                  label: Text('Music'),
                  avatar: Icon(Icons.music_note, size: 16),
                  onPressed: () => _quickRecord('music'),
                ),
                ActionChip(
                  label: Text('Ambient'),
                  avatar: Icon(Icons.nature, size: 16),
                  onPressed: () => _quickRecord('ambient'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(List<EnhancedAudioModel> audios) {
    final totalFiles = audios.length;
    final totalSize = audios.fold<int>(
      0,
      (sum, audio) => sum + audio.fileSizeBytes,
    );
    final totalDuration = audios.fold<int>(
      0,
      (sum, audio) => sum + audio.durationMs,
    );
    final favoriteCount = audios.where((audio) => audio.isFavorite).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Files',
            '$totalFiles',
            Icons.library_music,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Total Size',
            _formatBytes(totalSize),
            Icons.storage,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Total Duration',
            _formatDuration(Duration(milliseconds: totalDuration)),
            Icons.timer,
          ),
        ),
        Expanded(
          child: _buildStatCard('Favorites', '$favoriteCount', Icons.favorite),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(List<EnhancedAudioModel> audios) {
    final categoryCount = <String, int>{};
    for (final audio in audios) {
      final category = audio.category ?? 'Other';
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Files by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...categoryCount.entries.map(
              (entry) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(entry.key),
                      color: _getCategoryColor(entry.key),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.key.replaceAll('_', ' ').titleCase),
                    ),
                    Text('${entry.value}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageChart(List<EnhancedAudioModel> audios) {
    final playedFiles = audios.where((audio) => audio.playCount > 0).length;
    final averagePlayCount = audios.isEmpty
        ? 0.0
        : audios.fold<int>(0, (sum, audio) => sum + audio.playCount) /
              audios.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildUsageRow('Files Played', '$playedFiles / ${audios.length}'),
            _buildUsageRow(
              'Average Plays',
              averagePlayCount.toStringAsFixed(1),
            ),
            _buildUsageRow(
              'Most Played',
              '${audios.isEmpty ? 0 : audios.map((a) => a.playCount).reduce((a, b) => a > b ? a : b)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTopFiles(List<EnhancedAudioModel> audios) {
    final sortedByPlays = audios.where((audio) => audio.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Played Files',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...sortedByPlays
                .take(5)
                .map(
                  (audio) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(audio.category),
                      child: Icon(
                        _getCategoryIcon(audio.category),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(audio.title ?? audio.fileName),
                    subtitle: Text(
                      '${audio.durationFormatted} • ${audio.category?.replaceAll('_', ' ').titleCase ?? 'Other'}',
                    ),
                    trailing: Text('${audio.playCount} plays'),
                    dense: true,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  List<EnhancedAudioModel> _filterAndSortAudios(
    List<EnhancedAudioModel> audios,
  ) {
    var filtered = audios.where((audio) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle =
            audio.title?.toLowerCase().contains(query) ?? false;
        final matchesFileName = audio.fileName.toLowerCase().contains(query);
        final matchesTags = audio.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        final matchesDescription =
            audio.description?.toLowerCase().contains(query) ?? false;

        if (!matchesTitle &&
            !matchesFileName &&
            !matchesTags &&
            !matchesDescription) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'All' && audio.category != _selectedCategory) {
        return false;
      }

      // Favorites filter
      if (_showFavoritesOnly && !audio.isFavorite) {
        return false;
      }

      // Archived filter
      if (_showArchivedOnly != audio.isArchived) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'Recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Name A-Z':
        filtered.sort(
          (a, b) => (a.title ?? a.fileName).compareTo(b.title ?? b.fileName),
        );
        break;
      case 'Name Z-A':
        filtered.sort(
          (a, b) => (b.title ?? b.fileName).compareTo(a.title ?? a.fileName),
        );
        break;
      case 'Duration':
        filtered.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
      case 'Size':
        filtered.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case 'Most Played':
        filtered.sort((a, b) => b.playCount.compareTo(a.playCount));
        break;
    }

    return filtered;
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'voice_note':
        return Colors.blue;
      case 'music':
        return Colors.purple;
      case 'meeting':
        return Colors.green;
      case 'ambient':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'voice_note':
        return Icons.mic;
      case 'music':
        return Icons.music_note;
      case 'meeting':
        return Icons.meeting_room;
      case 'ambient':
        return Icons.nature;
      default:
        return Icons.audiotrack;
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Audio Files'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by title, filename, tags, or description',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => _searchQuery = value,
          onSubmitted: (value) {
            setState(() => _searchQuery = value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'sort':
        _showSortDialog();
        break;
      case 'export':
        _exportAllAudio();
        break;
      case 'cleanup':
        _cleanupStorage();
        break;
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sort & Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _sortBy,
              isExpanded: true,
              items: _sortOptions
                  .map(
                    (option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _sortBy = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _quickRecord(String category) {
    // Implementation for quick recording with predefined category
  }

  void _editAudio(EnhancedAudioModel audio) {
    // Implementation for editing audio metadata
  }

  void _shareAudio(EnhancedAudioModel audio) {
    // Implementation for sharing audio
  }

  void _exportAudio(EnhancedAudioModel audio) {
    // Implementation for exporting audio
  }

  void _exportAllAudio() {
    // Implementation for exporting all audio files
  }

  void _toggleArchive(EnhancedAudioModel audio) {
    if (audio.isArchived) {
      audio.unarchive();
    } else {
      audio.archive();
    }
    setState(() {});
  }

  void _deleteAudio(EnhancedAudioModel audio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Audio'),
        content: Text(
          'Are you sure you want to delete "${audio.title ?? audio.fileName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Delete file from storage
              final file = File(audio.filePath);
              if (await file.exists()) {
                await file.delete();
              }

              // Delete from database
              await audio.delete();

              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _cleanupStorage() {
    // Implementation for cleaning up unused files
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes % 60);
    final seconds = twoDigits(duration.inSeconds % 60);

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

extension StringExtensions on String {
  String get titleCase {
    return split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
