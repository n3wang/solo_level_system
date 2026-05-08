import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/long_break_queue_item_model.dart';
import 'package:solo_level_system/utils/long_break_queue_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showLongBreakModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: const _LongBreakSheetBody(),
    ),
  );
}

class _LongBreakSheetBody extends StatefulWidget {
  const _LongBreakSheetBody();

  @override
  State<_LongBreakSheetBody> createState() => _LongBreakSheetBodyState();
}

class _LongBreakSheetBodyState extends State<_LongBreakSheetBody> {
  final _urlController = TextEditingController();
  final _sheetReminderController = TextEditingController();
  Timer? _sheetReminderSaveDebounce;
  bool _sheetReminderLoaded = false;

  bool _hasChapters = false;
  bool _useCustomName = false;
  final _customNameController = TextEditingController();

  List<LongBreakQueueItemModel> _active = [];
  List<LongBreakQueueItemModel> _archived = [];
  bool _loading = true;
  bool _showArchived = false;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadSheetReminder();
    _reload();
  }

  Future<void> _loadSheetReminder() async {
    final text = await LongBreakQueueService.getSheetReminderNote();
    if (!mounted) return;
    _sheetReminderController.text = text;
    setState(() => _sheetReminderLoaded = true);
  }

  void _scheduleSaveSheetReminder() {
    _sheetReminderSaveDebounce?.cancel();
    _sheetReminderSaveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(
        LongBreakQueueService.saveSheetReminderNote(_sheetReminderController.text),
      );
    });
  }

  @override
  void dispose() {
    _sheetReminderSaveDebounce?.cancel();
    unawaited(
      LongBreakQueueService.saveSheetReminderNote(_sheetReminderController.text),
    );
    _sheetReminderController.dispose();
    _urlController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final a = await LongBreakQueueService.activeItems();
    final z = await LongBreakQueueService.archivedItems();
    if (!mounted) return;
    setState(() {
      _active = a;
      _archived = z;
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Add a playlist or video link first.')),
      );
      return;
    }
    final custom =
        _useCustomName ? _customNameController.text.trim() : '';
    final item = LongBreakQueueItemModel(
      id: LongBreakQueueService.newId(),
      url: url,
      customName: custom.isEmpty ? null : custom,
      hasChapters: _hasChapters,
      currentChapter: 1,
    );
    await LongBreakQueueService.save(item);
    _urlController.clear();
    if (_useCustomName) _customNameController.clear();
    await _reload();
  }

  Future<void> _persist(LongBreakQueueItemModel item) async {
    await LongBreakQueueService.save(item);
    await _reload();
  }

  Future<void> _archive(LongBreakQueueItemModel item) async {
    item.isArchived = true;
    await LongBreakQueueService.save(item);
    await _reload();
  }

  Future<void> _restore(LongBreakQueueItemModel item) async {
    item.isArchived = false;
    await LongBreakQueueService.save(item);
    await _reload();
  }

  Future<void> _deleteForever(LongBreakQueueItemModel item) async {
    await LongBreakQueueService.delete(item.id);
    await _reload();
  }

  Future<void> _openExternal(String raw) async {
    var u = raw.trim();
    if (u.isEmpty) return;
    if (!u.contains('://')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $u')),
      );
    }
  }

  Future<void> _copyUrl(String raw) async {
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppUiSizes.md,
                  AppUiSizes.md,
                  AppUiSizes.md,
                  AppUiSizes.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sheetReminderController,
                        enabled: _sheetReminderLoaded,
                        decoration: InputDecoration(
                          labelText: 'Your reminder',
                          hintText:
                              'e.g. Finish lecture 3, then grab lunch…',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          helperText: 'Saved automatically',
                          helperMaxLines: 1,
                        ),
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 5,
                        onChanged: (_) => _scheduleSaveSheetReminder(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppUiSizes.md,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'Playlist or video link',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: AppUiSizes.sm),
                        IconButton.filled(
                          onPressed: _loading ? null : _addItem,
                          icon: const Icon(Icons.add),
                          tooltip: 'Add to queue',
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Has chapters (series-style)'),
                      value: _hasChapters,
                      onChanged:
                          _loading ? null : (v) {
                            setState(() => _hasChapters = v ?? false);
                          },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Custom name (optional)'),
                      value: _useCustomName,
                      onChanged:
                          _loading ? null : (v) {
                            setState(() => _useCustomName = v ?? false);
                          },
                    ),
                    if (_useCustomName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppUiSizes.sm),
                        child: TextField(
                          controller: _customNameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Watch list',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppUiSizes.xs),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(AppUiSizes.lg),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final incomplete =
                              _active.where((e) => !e.isCompleted).toList();
                          final completed =
                              _active.where((e) => e.isCompleted).toList();
                          final widgets = <Widget>[];

                          if (_active.isEmpty) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppUiSizes.lg,
                                ),
                                child: Text(
                                  'Nothing here yet. Paste a link and tap +.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            if (incomplete.isEmpty) {
                              widgets.add(
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppUiSizes.sm,
                                  ),
                                  child: Text(
                                    'No active items — tap Completed below to view finished ones.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              widgets.addAll(
                                incomplete.map((e) => _itemTile(context, e)),
                              );
                            }

                            if (completed.isNotEmpty) {
                              widgets.add(const SizedBox(height: AppUiSizes.sm));
                              widgets.add(
                                InkWell(
                                  onTap: () {
                                    setState(
                                      () => _showCompleted = !_showCompleted,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppUiSizes.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _showCompleted
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                        ),
                                        Text(
                                          'Completed (${completed.length})',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (_showCompleted) {
                                widgets.addAll(
                                  completed.map((e) => _itemTile(context, e)),
                                );
                              }
                            }
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: widgets,
                          );
                        },
                      ),

                    if (_archived.isNotEmpty) ...[
                      const SizedBox(height: AppUiSizes.sm),
                      InkWell(
                        onTap: () {
                          setState(() => _showArchived = !_showArchived);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppUiSizes.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showArchived
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                              Text(
                                'Archived (${_archived.length})',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showArchived)
                        ..._archived.map((e) => _archivedTile(context, e)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemTile(BuildContext context, LongBreakQueueItemModel e) {
    final theme = Theme.of(context);

    final tileContent = GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 200) _bumpChapter(e, 1);
        if (v < -200) _bumpChapter(e, -1);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppUiSizes.sm),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUiSizes.xs,
              vertical: AppUiSizes.xxs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: e.isCompleted,
                  onChanged: (_) {
                    e.isCompleted = !e.isCompleted;
                    _persist(e);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.displayLabel(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration:
                              e.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                          color:
                              e.isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                        ),
                      ),
                      Text(
                        e.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.hasChapters) ...[
                  IconButton(
                    tooltip: 'Previous chapter',
                    icon: const Icon(Icons.remove),
                    onPressed: () => _bumpChapter(e, -1),
                  ),
                  IconButton(
                    tooltip: 'Next chapter',
                    icon: const Icon(Icons.add),
                    onPressed: () => _bumpChapter(e, 1),
                  ),
                ],
                IconButton(
                  tooltip: 'Open link',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openExternal(e.url),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyUrl(e.url),
                ),
                IconButton(
                  tooltip: 'Archive',
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () => _archive(e),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return tileContent;
  }

  void _bumpChapter(LongBreakQueueItemModel e, int delta) {
    if (!e.hasChapters) return;
    final next = (e.currentChapter + delta).clamp(1, 9999);
    if (next == e.currentChapter) return;
    e.currentChapter = next;
    _persist(e);
  }

  Widget _archivedTile(BuildContext context, LongBreakQueueItemModel e) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUiSizes.sm),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          title: Text(
            e.displayLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Text(e.url, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _restore(e),
                child: const Text('Restore'),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteForever(e),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
