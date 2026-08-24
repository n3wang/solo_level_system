import 'package:flutter/material.dart';
import 'package:solo_level_system/screens/guild_detail_screen.dart';
import 'package:solo_level_system/services/auth_service.dart';
import 'package:solo_level_system/services/guild_service.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

const int kMaxGuildsPerUser = 3;

class GuildsScreen extends StatefulWidget {
  const GuildsScreen({super.key});

  @override
  State<GuildsScreen> createState() => _GuildsScreenState();
}

class _GuildsScreenState extends State<GuildsScreen> {
  List<Map<String, dynamic>> _guilds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AccountSession.instance.loggedIn.value) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final guilds = await GuildService.instance.fetchMine();
    if (!mounted) return;
    setState(() {
      _guilds = guilds;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AccountSession.instance.loggedIn,
      builder: (context, loggedIn, _) {
        if (!loggedIn) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sign in from Settings → Account to create or join a guild',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _guilds.length >= kMaxGuildsPerUser
                          ? null
                          : _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guilds.length >= kMaxGuildsPerUser
                          ? null
                          : _showJoinDialog,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Join'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_guilds.length}/$kMaxGuildsPerUser guilds',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_guilds.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No guilds yet — create one or join with a code'),
                  ),
                )
              else
                ..._guilds.map(_buildGuildCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuildCard(Map<String, dynamic> guild) {
    final name = guild['name']?.toString() ?? 'Guild';
    final code = guild['code']?.toString() ?? '';
    final isOwner = guild['isOwner'] == true;
    final memberCount = guild['memberCount'] is int ? guild['memberCount'] as int : 0;

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text('Code: $code · $memberCount member${memberCount == 1 ? '' : 's'}'),
        trailing: isOwner
            ? const Chip(label: Text('Owner'), visualDensity: VisualDensity.compact)
            : null,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GuildDetailScreen(
                guildId: guild['id'].toString(),
                initialName: name,
              ),
            ),
          );
          if (mounted) _load();
        },
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Guild'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Guild name'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                showAppSnack(context, text: 'Enter a guild name');
                return;
              }
              final result = await GuildService.instance.create(
                name: name,
                password: passwordController.text.trim().isEmpty
                    ? null
                    : passwordController.text.trim(),
              );
              if (!context.mounted) return;
              if (!result.success) {
                showAppSnack(context, text: result.error!);
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _load();
  }

  Future<void> _showJoinDialog() async {
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Guild'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: '6-character code'),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (if required)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) {
                showAppSnack(context, text: 'Enter a guild code');
                return;
              }
              final result = await GuildService.instance.join(
                code: code,
                password: passwordController.text.trim().isEmpty
                    ? null
                    : passwordController.text.trim(),
              );
              if (!context.mounted) return;
              if (!result.success) {
                showAppSnack(context, text: result.error!);
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (joined == true) _load();
  }
}
