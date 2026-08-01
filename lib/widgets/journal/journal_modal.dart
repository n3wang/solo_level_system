import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/enhanced_audio_model.dart';
import 'package:solo_level_system/models/journal_entry_model.dart';
import 'package:solo_level_system/utils/image_utils.dart';
import 'package:solo_level_system/utils/journal_service.dart';
import 'package:solo_level_system/widgets/common/centered_app_modal.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';
import 'package:solo_level_system/widgets/common/settings_rect_chip.dart';
import 'package:solo_level_system/widgets/game_icon_widget.dart';

class JournalModalResult {
  /// True when the modal was opened after a finished focus session and the
  /// user dismissed it (paused break should resume).
  final bool resumeBreak;
  final String? audioPath;
  final String? imagePath;

  const JournalModalResult({
    this.resumeBreak = false,
    this.audioPath,
    this.imagePath,
  });
}

/// Opens the shared journal as a floating centered modal.
Future<JournalModalResult?> showJournalModal(
  BuildContext context, {
  bool awaitingBreakResume = false,
  String source = 'free',
  String? projectName,

  /// When set, ensures an in-progress workout session note for grouping.
  String? workoutSessionId,

  /// Prefer attaching composer input to the active/latest session note.
  bool preferSessionNotes = false,

  /// Hex accent for project/set grouping (misc falls back to primary).
  String? accentColorHex,
}) {
  return showCenteredAppModal<JournalModalResult>(
    context: context,
    barrierDismissible: true,
    heightFraction: 0.86,
    builder: (ctx) => JournalModal(
      awaitingBreakResume: awaitingBreakResume,
      source: source,
      projectName: projectName,
      workoutSessionId: workoutSessionId,
      preferSessionNotes: preferSessionNotes,
      accentColorHex: accentColorHex,
    ),
  );
}

class JournalOpenButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String tooltip;

  /// When non-null, shows whether post-session auto-open is enabled.
  final bool? autoOpenAfterSession;

  const JournalOpenButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.tooltip = 'Journal',
    this.autoOpenAfterSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoOpen = autoOpenAfterSession;
    final tip = autoOpen == null
        ? tooltip
        : autoOpen
            ? 'Journal · Auto-open On (long-press to turn off)'
            : 'Journal · Auto-open Off (long-press to turn on)';
    return Tooltip(
      message: tip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.85,
        ),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  autoOpen == false
                      ? Icons.menu_book_outlined
                      : Icons.menu_book,
                  size: 22,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: autoOpen == false ? 0.55 : 0.85,
                  ),
                ),
                if (autoOpen != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: autoOpen
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JournalModal extends StatefulWidget {
  final bool awaitingBreakResume;
  final String source;
  final String? projectName;
  final String? workoutSessionId;
  final bool preferSessionNotes;
  final String? accentColorHex;

  const JournalModal({
    super.key,
    this.awaitingBreakResume = false,
    this.source = 'free',
    this.projectName,
    this.workoutSessionId,
    this.preferSessionNotes = false,
    this.accentColorHex,
  });

  @override
  State<JournalModal> createState() => _JournalModalState();
}

class _JournalModalState extends State<JournalModal> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _datePickerScrollController = ScrollController();

  late DateTime _selectedDay;
  bool _showDatePicker = false;

  /// Loaded only when the date selector opens (not while viewing a day).
  List<DateTime>? _availableDays;

  bool _campaignMode = false;
  bool _sendingText = false;
  bool _sessionNoteEnabled = false;
  String? _attachSessionId;
  int _lastFeedLength = -1;

  String? get _activeParentSessionId =>
      _sessionNoteEnabled ? _attachSessionId : null;

  bool get _canAttachSessionNote => _attachSessionId != null;

  @override
  void initState() {
    super.initState();
    _selectedDay = JournalService.dayOnly(DateTime.now());
    _campaignMode = JournalService.campaignModeEnabled;
    // After a completed focus session, or during an active workout set.
    _sessionNoteEnabled =
        widget.awaitingBreakResume || widget.preferSessionNotes;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await JournalService.ensureBox();
    await JournalService.ensureDailyQuote(day: _selectedDay);

    if (widget.workoutSessionId != null &&
        widget.workoutSessionId!.trim().isNotEmpty) {
      final workoutNote = await JournalService.ensureActiveWorkoutSessionNote(
        workoutSessionId: widget.workoutSessionId!,
        routineName: widget.projectName ?? 'Workout',
        accentColorHex: widget.accentColorHex,
      );
      _attachSessionId = workoutNote.id;
      _sessionNoteEnabled = true;
    } else {
      final latest = JournalService.latestSessionForDay(
        _selectedDay,
        source: widget.source == 'free' ? null : widget.source,
      );
      _attachSessionId = latest?.id;
      if ((widget.awaitingBreakResume || widget.preferSessionNotes) &&
          _attachSessionId != null) {
        _sessionNoteEnabled = true;
      }
    }

    if (mounted) {
      setState(() {});
      _scrollToEnd(jump: true);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _datePickerScrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleCampaign(bool enabled) async {
    await JournalService.setCampaignModeEnabled(enabled);
    await JournalService.ensureDailyQuote(day: _selectedDay);
    if (!mounted) return;
    setState(() => _campaignMode = enabled);
  }

  Future<void> _toggleDatePicker() async {
    if (_showDatePicker) {
      setState(() => _showDatePicker = false);
      return;
    }
    // Lazy: only scan day keys when opening the selector.
    final days = JournalService.daysWithEntries(includeToday: true);
    setState(() {
      _availableDays = days;
      _showDatePicker = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_datePickerScrollController.hasClients) return;
      // reverse:true → offset 0 shows the latest month at the bottom edge.
      _datePickerScrollController.jumpTo(0);
    });
  }

  Future<void> _selectDay(DateTime day) async {
    final next = JournalService.dayOnly(day);
    setState(() {
      _selectedDay = next;
      _showDatePicker = false;
      _lastFeedLength = -1;
    });
    await JournalService.ensureDailyQuote(day: next);
    if (!mounted) return;
    setState(() {});
    _scrollToEnd(jump: true);
  }

  static const _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<void> _citeQuote(JournalEntryModel quoteEntry) async {
    final quote = (quoteEntry.text ?? '').trim();
    if (quote.isEmpty) return;
    final author =
        (quoteEntry.metadata['author'] as String?)?.trim().isNotEmpty == true
        ? quoteEntry.metadata['author'] as String
        : 'Unknown';
    await JournalService.addCitation(
      quote: quote,
      author: author,
      source: widget.source,
      parentSessionId: _activeParentSessionId,
    );
    await _scrollToEnd();
  }

  Future<void> _submitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sendingText) return;
    setState(() => _sendingText = true);
    try {
      await JournalService.addText(
        text: text,
        source: widget.source,
        parentSessionId: _activeParentSessionId,
      );
      _textController.clear();
      await _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sendingText = false);
    }
  }

  Future<void> _capturePhoto() async {
    final path = await capturePhoto(context);
    if (path == null || !mounted) return;
    await JournalService.addImage(
      mediaPath: path,
      source: widget.source,
      parentSessionId: _activeParentSessionId,
    );
    await _scrollToEnd();
  }

  Future<void> _onAudioCaptured(EnhancedAudioModel audio) async {
    await JournalService.addAudio(
      mediaPath: audio.filePath,
      durationMs: audio.durationMs,
      source: widget.source,
      parentSessionId: _activeParentSessionId,
    );
    if (!Hive.isBoxOpen('audioFiles')) {
      await Hive.openBox<EnhancedAudioModel>('audioFiles');
    }
    await Hive.box<EnhancedAudioModel>('audioFiles').add(audio);
    if (!mounted) return;
    await _scrollToEnd();
  }

  Future<void> _scrollToEnd({bool jump = false}) async {
    await Future<void>.delayed(Duration(milliseconds: jump ? 16 : 80));
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
      // Layout can grow after first paint (images/audio); pin again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
      return;
    }
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _pinToLatestIfNeeded(int feedLength) {
    if (feedLength <= 0) {
      _lastFeedLength = feedLength;
      return;
    }
    final grew = feedLength != _lastFeedLength;
    _lastFeedLength = feedLength;
    if (!grew && _scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_scrollToEnd(jump: !grew));
    });
  }

  String _formatDate(DateTime d) => '${d.month} - ${d.day} - ${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppUiSizes.lg,
            AppUiSizes.md,
            AppUiSizes.md,
            AppUiSizes.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _toggleDatePicker,
                  borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDate(_selectedDay),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showDatePicker
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: AppColorPalette.grey700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OnOffToggle(
                value: _campaignMode,
                onChanged: _toggleCampaign,
                onLabel: 'Campaign',
                offLabel: 'Regular',
                activeColor: AppColorPalette.primary,
                size: SettingsRectChipSize.compact,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
        Expanded(
          child: _showDatePicker
              ? _buildDatePicker(theme)
              : (!Hive.isBoxOpen(JournalService.boxName)
                    ? const Center(child: CircularProgressIndicator())
                    : ValueListenableBuilder(
                        valueListenable: Hive.box<JournalEntryModel>(
                          JournalService.boxName,
                        ).listenable(),
                        builder: (context, box, _) {
                          // Lazy: only materialize the selected day's entries.
                          final entries = JournalService.entriesForDay(
                            _selectedDay,
                          );
                          JournalEntryModel? quote;
                          for (final e in entries) {
                            if (e.isQuote) {
                              quote = e;
                              break;
                            }
                          }
                          final feed = _buildJournalFeed(entries);
                          final primary = theme.primaryColor;
                          _pinToLatestIfNeeded(feed.length);

                          return Column(
                            children: [
                              if (quote != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppUiSizes.lg,
                                    AppUiSizes.md,
                                    AppUiSizes.lg,
                                    0,
                                  ),
                                  child: _QuoteTile(
                                    entry: quote,
                                    onCite: () => _citeQuote(quote!),
                                  ),
                                ),
                              Expanded(
                                child: feed.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                            AppUiSizes.xxl,
                                          ),
                                          child: Text(
                                            widget.awaitingBreakResume
                                                ? 'Session complete. Capture a note, clip, or photo — then close to start your break.'
                                                : 'Your journal is empty for this day.\nWrite, record, or snap something.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      AppColorPalette.grey700,
                                                  height: 1.4,
                                                ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: _scrollController,
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          AppUiSizes.lg,
                                          AppUiSizes.md,
                                          AppUiSizes.lg,
                                          AppUiSizes.md,
                                        ),
                                        itemCount: feed.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(
                                              height: AppUiSizes.md,
                                            ),
                                        itemBuilder: (context, index) {
                                          return _FeedItemView(
                                            item: feed[index],
                                            primary: primary,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      )),
        ),
        if (!_showDatePicker)
          _ComposerBar(
            controller: _textController,
            sending: _sendingText,
            showSessionNoteToggle: _canAttachSessionNote,
            sessionNoteEnabled: _sessionNoteEnabled,
            onSessionNoteChanged: (v) =>
                setState(() => _sessionNoteEnabled = v),
            onSubmitText: _submitText,
            onCapturePhoto: _capturePhoto,
            onAudioCaptured: _onAudioCaptured,
          ),
      ],
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    final days = _availableDays ?? const <DateTime>[];
    // Oldest→newest groups; reverse ListView + reverse index → latest at bottom.
    final groups = JournalService.groupDaysByMonth(days);
    return ListView.builder(
      controller: _datePickerScrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppUiSizes.lg,
        AppUiSizes.md,
        AppUiSizes.lg,
        AppUiSizes.lg,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[groups.length - 1 - index];
        final monthLabel = '${_monthNames[group.month - 1]} ${group.year}';
        return Padding(
          padding: const EdgeInsets.only(bottom: AppUiSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppUiSizes.sm),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < group.days.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '|',
                          style: TextStyle(
                            color: AppColorPalette.grey700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    _DateChip(
                      day: group.days[i].day,
                      selected: JournalService.isSameDay(
                        group.days[i],
                        _selectedDay,
                      ),
                      onTap: () => _selectDay(group.days[i]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  final int day;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '$day',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? theme.primaryColor : null,
            decoration: selected ? TextDecoration.underline : null,
            decorationColor: theme.primaryColor,
          ),
        ),
      ),
    );
  }
}

List<_FeedItem> _buildJournalFeed(List<JournalEntryModel> entries) {
  final sessionsById = {
    for (final e in entries.where((e) => e.isSession)) e.id: e,
  };
  final childrenBySession = <String, List<JournalEntryModel>>{};
  final attachedIds = <String>{};

  for (final entry in entries) {
    if (entry.isSession || entry.isQuote) continue;
    final parentId = JournalService.parentSessionIdOf(entry);
    if (parentId == null || !sessionsById.containsKey(parentId)) continue;
    childrenBySession.putIfAbsent(parentId, () => []).add(entry);
    attachedIds.add(entry.id);
  }

  final feed = <_FeedItem>[];
  for (final entry in entries) {
    if (attachedIds.contains(entry.id)) continue;
    // Quotes are pinned above the scrollable feed.
    if (entry.isQuote) continue;
    if (entry.isSession) {
      feed.add(
        _FeedSessionBlock(
          session: entry,
          children: childrenBySession[entry.id] ?? const [],
        ),
      );
      continue;
    }
    feed.add(_FeedLoose(entry));
  }
  return feed;
}

sealed class _FeedItem {
  const _FeedItem();
}

class _FeedLoose extends _FeedItem {
  final JournalEntryModel entry;
  const _FeedLoose(this.entry);
}

class _FeedSessionBlock extends _FeedItem {
  final JournalEntryModel session;
  final List<JournalEntryModel> children;
  const _FeedSessionBlock({required this.session, required this.children});
}

class _FeedItemView extends StatelessWidget {
  final _FeedItem item;
  final Color primary;

  const _FeedItemView({required this.item, required this.primary});

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      _FeedLoose(:final entry) => _JournalContentTile(entry: entry),
      _FeedSessionBlock(:final session, :final children) => _SessionBlock(
        session: session,
        children: children,
        accent: JournalService.resolveGroupingColor(session) ?? primary,
      ),
    };
  }
}

class _SessionBlock extends StatelessWidget {
  final JournalEntryModel session;
  final List<JournalEntryModel> children;
  final Color accent;

  const _SessionBlock({
    required this.session,
    required this.children,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = JournalService.formatSessionTitle(session);

    final header = Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        height: 1.25,
      ),
    );

    if (children.isEmpty) return header;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: AppUiSizes.sm),
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppUiSizes.sm),
                  _JournalContentTile(entry: children[i]),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppUiSizes.sm),
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalContentTile extends StatelessWidget {
  final JournalEntryModel entry;

  const _JournalContentTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    if (entry.isAudio) {
      return _AudioTile(
        path: entry.mediaPath ?? '',
        durationMs: entry.durationMs,
      );
    }
    if (entry.isImage) {
      return _ImageTile(path: entry.mediaPath ?? '');
    }
    return _TextTile(entry: entry);
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool showSessionNoteToggle;
  final bool sessionNoteEnabled;
  final ValueChanged<bool> onSessionNoteChanged;
  final VoidCallback onSubmitText;
  final VoidCallback onCapturePhoto;
  final ValueChanged<EnhancedAudioModel> onAudioCaptured;

  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.showSessionNoteToggle,
    required this.sessionNoteEnabled,
    required this.onSessionNoteChanged,
    required this.onSubmitText,
    required this.onCapturePhoto,
    required this.onAudioCaptured,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppUiSizes.md,
            AppUiSizes.sm,
            AppUiSizes.md,
            AppUiSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSessionNoteToggle) ...[
                SettingsRectChip(
                  label: 'session note',
                  selected: sessionNoteEnabled,
                  activeColor: accent,
                  size: SettingsRectChipSize.compact,
                  onTap: () => onSessionNoteChanged(!sessionNoteEnabled),
                ),
                const SizedBox(height: AppUiSizes.sm),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSubmitText(),
                      decoration: InputDecoration(
                        hintText: 'text input',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppUiSizes.md,
                          vertical: AppUiSizes.sm + 2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppUiSizes.radiusMd,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Send',
                          onPressed: sending ? null : onSubmitText,
                          icon: Icon(
                            Icons.send_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppUiSizes.sm),
                  _JournalMicButton(onRecordingComplete: onAudioCaptured),
                  const SizedBox(width: AppUiSizes.sm),
                  _ComposerIconButton(
                    color: AppColorPalette.warning,
                    icon: Icons.photo_camera_outlined,
                    onTap: onCapturePhoto,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ComposerIconButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _JournalMicButton extends StatefulWidget {
  final ValueChanged<EnhancedAudioModel> onRecordingComplete;

  const _JournalMicButton({required this.onRecordingComplete});

  @override
  State<_JournalMicButton> createState() => _JournalMicButtonState();
}

class _JournalMicButtonState extends State<_JournalMicButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _stopping = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isRecording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/journal_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      setState(() {
        _isRecording = true;
        _duration = Duration.zero;
      });
      _pulse.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      });
    } catch (e) {
      debugPrint('Journal mic start failed: $e');
    }
  }

  Future<void> _stop() async {
    if (_stopping || !_isRecording) return;
    _stopping = true;
    _timer?.cancel();
    _pulse.stop();
    try {
      final path = await _recorder.stop();
      if (path != null) {
        widget.onRecordingComplete(
          EnhancedAudioModel(
            filePath: path,
            fileName: path.replaceAll('\\', '/').split('/').last,
            createdAt: DateTime.now(),
            durationMs: _duration.inMilliseconds,
            fileSizeBytes: 0,
            format: 'wav',
            bitRate: 128000,
            sampleRate: 44100,
            channels: 1,
            title: 'Journal Recording',
            description: 'Journal audio capture',
            tags: const ['journal', 'session'],
            category: 'session',
          ),
        );
      }
    } catch (e) {
      debugPrint('Journal mic stop failed: $e');
    } finally {
      _stopping = false;
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColorPalette.info;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final scale = _isRecording ? 1 + (_pulse.value * 0.08) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Material(
            color: _isRecording ? AppColorPalette.error : base,
            borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback onCite;

  const _QuoteTile({required this.entry, required this.onCite});

  Future<void> _randomize(BuildContext context) async {
    final day = entry.createdAt;
    await JournalService.randomizeDailyQuote(day: day);
  }

  Future<void> _openDetails(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    var current = entry;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final author =
                (current.metadata['author'] as String?)?.trim().isNotEmpty ==
                    true
                ? current.metadata['author'] as String
                : 'Quote';
            final about =
                (current.metadata['aboutAuthor'] as String?)?.trim() ?? '';
            final imageIndex = current.metadata['imageIndex'] as int?;

            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: imageIndex != null && imageIndex > 0
                          ? MotivationIconWidget(
                              imageIndex: imageIndex,
                              size: 96,
                            )
                          : Icon(
                              Icons.format_quote,
                              size: 64,
                              color: scheme.primary,
                            ),
                    ),
                    if (about.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        about,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      current.text ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final next =
                                await JournalService.randomizeDailyQuote(
                                  day: current.createdAt,
                                );
                            if (next == null) return;
                            setDialogState(() => current = next);
                          },
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Random'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColorPalette.error;
    return Material(
      color: const Color(0xFFFFE4EC),
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(AppUiSizes.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: 'Save quote to journal',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  onTap: onCite,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.format_quote_rounded,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppUiSizes.sm),
              Expanded(
                child: Text(
                  entry.text ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: AppUiSizes.sm),
              InkWell(
                borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                onTap: () => _randomize(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.casino_outlined, size: 18, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextTile extends StatelessWidget {
  final JournalEntryModel entry;
  const _TextTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCitation = JournalService.isCitation(entry);
    final author = (entry.metadata['author'] as String?)?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppUiSizes.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      ),
      child: isCitation
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.text ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: AppUiSizes.sm),
                  Text(
                    '--- $author',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColorPalette.grey700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            )
          : Text(
              entry.text ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String path;
  const _ImageTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget image;
    if (path.isEmpty) {
      image = const SizedBox.shrink();
    } else if (kIsWeb) {
      image = Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColorPalette.grey700,
            ),
          );
        },
      );
    } else {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColorPalette.grey700,
            ),
          );
        },
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        child: Container(
          width: 120,
          height: 120,
          color: theme.colorScheme.surfaceContainerHighest,
          child: image,
        ),
      ),
    );
  }
}

class _AudioTile extends StatefulWidget {
  final String path;
  final int? durationMs;

  const _AudioTile({required this.path, this.durationMs});

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  late final ap.AudioPlayer _player;
  StreamSubscription<ap.PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);
    if (widget.durationMs != null && widget.durationMs! > 0) {
      _duration = Duration(milliseconds: widget.durationMs!);
    }
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == ap.PlayerState.playing);
    });
    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });
    if (widget.path.isNotEmpty) {
      final source = kIsWeb
          ? ap.UrlSource(widget.path)
          : ap.DeviceFileSource(widget.path);
      unawaited(_player.setSource(source));
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.path.isEmpty) return;
    final state = _player.state;
    if (state == ap.PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (state == ap.PlayerState.paused) {
      await _player.resume();
      return;
    }
    final source = kIsWeb
        ? ap.UrlSource(widget.path)
        : ap.DeviceFileSource(widget.path);
    if (state == ap.PlayerState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play(source);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = max(_duration.inMilliseconds, 1);
    final progress = (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppUiSizes.md,
        vertical: AppUiSizes.sm + 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: theme.primaryColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.35),
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColorPalette.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
