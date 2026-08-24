import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/services/guild_service.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';

class GuildDetailScreen extends StatefulWidget {
  const GuildDetailScreen({super.key, required this.guildId, required this.initialName});

  final String guildId;
  final String initialName;

  @override
  State<GuildDetailScreen> createState() => _GuildDetailScreenState();
}

class _GuildDetailScreenState extends State<GuildDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _savingSharing = false;
  bool _posting = false;
  final _postController = TextEditingController();

  late bool _shareAllProjects;
  late Set<String> _sharedProjectNames;
  late bool _shareFocusSessions;
  late bool _shareWorkoutSessions;

  @override
  void initState() {
    super.initState();
    _shareAllProjects = true;
    _sharedProjectNames = {};
    _shareFocusSessions = true;
    _shareWorkoutSessions = true;
    _load();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await GuildService.instance.retryPostOutbox();
    final detail = await GuildService.instance.fetchDetail(widget.guildId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
      final mySharing = detail?['mySharing'];
      if (mySharing is Map) {
        _shareAllProjects = mySharing['shareAllProjects'] != false;
        _sharedProjectNames = (mySharing['sharedProjectNames'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};
        _shareFocusSessions = mySharing['shareFocusSessions'] != false;
        _shareWorkoutSessions = mySharing['shareWorkoutSessions'] != false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _detail?['name']?.toString() ?? widget.initialName;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('Could not load this guild'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCodeCard(),
                      const SizedBox(height: 20),
                      _buildRankingSection(),
                      const SizedBox(height: 20),
                      _buildSharingSection(),
                      const SizedBox(height: 20),
                      _buildFeedSection(),
                      const SizedBox(height: 20),
                      _buildOwnerAndLeaveSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCodeCard() {
    final code = _detail?['code']?.toString() ?? '';
    final hasPassword = _detail?['hasPassword'] == true;
    final memberCount = _detail?['memberCount'] is int ? _detail!['memberCount'] as int : 0;
    final link = '${AppEnvironment.apiBaseUrl}/g/$code';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code: $code', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '$memberCount member${memberCount == 1 ? '' : 's'}'
                    '${hasPassword ? ' · password protected' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy public link',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (mounted) showAppSnack(context, text: 'Link copied');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingSection() {
    final ranking = (_detail?['ranking'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ranking', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (ranking.isEmpty)
          const Text('No shared progress yet.')
        else
          ...ranking.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value as Map;
            final isMe = row['isMe'] == true;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(
                '${row['displayName']}${isMe ? ' (you)' : ''}',
                style: isMe ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
              trailing: Text('${row['totalMinutes'] ?? 0} min'),
            );
          }),
      ],
    );
  }

  Widget _buildSharingSection() {
    final box = Hive.isBoxOpen('projects') ? Hive.box<ProjectModel>('projects') : null;
    final projectNames = box?.values.map((p) => p.name).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My sharing', style: Theme.of(context).textTheme.titleMedium),
        OnOffToggleListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share all projects'),
          value: _shareAllProjects,
          onChanged: (value) => setState(() => _shareAllProjects = value),
        ),
        if (!_shareAllProjects) ...[
          if (projectNames.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('No projects yet'),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: projectNames.map((name) {
                final selected = _sharedProjectNames.contains(name);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _sharedProjectNames.add(name);
                    } else {
                      _sharedProjectNames.remove(name);
                    }
                  }),
                );
              }).toList(),
            ),
        ],
        OnOffToggleListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share focus sessions'),
          value: _shareFocusSessions,
          onChanged: (value) => setState(() => _shareFocusSessions = value),
        ),
        OnOffToggleListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share workout sessions'),
          value: _shareWorkoutSessions,
          onChanged: (value) => setState(() => _shareWorkoutSessions = value),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _savingSharing ? null : _saveSharing,
          child: const Text('Save sharing settings'),
        ),
      ],
    );
  }

  Future<void> _saveSharing() async {
    setState(() => _savingSharing = true);
    final ok = await GuildService.instance.updateSharing(
      widget.guildId,
      shareAllProjects: _shareAllProjects,
      sharedProjectNames: _sharedProjectNames.toList(),
      shareFocusSessions: _shareFocusSessions,
      shareWorkoutSessions: _shareWorkoutSessions,
    );
    if (!mounted) return;
    setState(() => _savingSharing = false);
    showAppSnack(context, text: ok ? 'Sharing settings saved' : 'Could not save — try again');
    if (ok) _load();
  }

  Widget _buildFeedSection() {
    final feed = (_detail?['feed'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feed', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _postController,
                decoration: const InputDecoration(
                  hintText: 'Post to the guild…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _posting ? null : _submitPost,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (feed.isEmpty)
          const Text('Nothing shared yet.')
        else
          ...feed.map((raw) {
            final item = raw as Map;
            final kind = item['kind']?.toString();
            final isPost = kind == 'post';
            final subtitle = isPost
                ? (item['text']?.toString() ?? '')
                : '${item['type'] == 'workout' ? 'Workout' : 'Focus session'}'
                    '${item['projectName'] != null ? ' · ${item['projectName']}' : ''}'
                    '${item['minutes'] != null ? ' · ${item['minutes']} min' : ''}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item['displayName']?.toString() ?? ''),
              subtitle: Text(subtitle),
            );
          }),
      ],
    );
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final ok = await GuildService.instance.post(widget.guildId, text);
    if (!mounted) return;
    setState(() => _posting = false);
    _postController.clear();
    showAppSnack(
      context,
      text: ok ? 'Posted' : 'Offline — will send once you\'re back online',
    );
    if (ok) _load();
  }

  Widget _buildOwnerAndLeaveSection() {
    final isOwner = _detail?['isOwner'] == true;
    final hasPassword = _detail?['hasPassword'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOwner) ...[
          Text('Guild settings', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(hasPassword ? 'Password protected' : 'No password'),
            trailing: TextButton(
              onPressed: _showPasswordDialog,
              child: Text(hasPassword ? 'Change' : 'Set password'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: _confirmLeave,
          child: const Text('Leave guild'),
        ),
      ],
    );
  }

  Future<void> _showPasswordDialog() async {
    final controller = TextEditingController();
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guild password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password (blank to remove)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await GuildService.instance.setPassword(
                widget.guildId,
                controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              if (context.mounted) Navigator.of(context).pop(ok);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave guild?'),
        content: const Text('You can rejoin later with the guild code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await GuildService.instance.leave(widget.guildId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      showAppSnack(context, text: 'Could not leave — try again');
    }
  }
}
