import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_acquisition_settings.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/pomodoro_model.dart';
import 'package:solo_level_system/models/project_model.dart';
import 'package:solo_level_system/models/user_progress_model.dart';
import 'package:solo_level_system/models/user_settings_model.dart';
import 'package:solo_level_system/services/desktop_shell_service.dart';
import 'package:solo_level_system/services/pomodoro_session_service.dart';
import 'package:solo_level_system/services/solo_sync_service.dart';
import 'package:solo_level_system/utils/background_music_service.dart';
import 'package:solo_level_system/utils/collectible_deck_seed_service.dart';
import 'package:solo_level_system/utils/database_utils.dart';
import 'package:solo_level_system/utils/journal_service.dart';
import 'package:solo_level_system/utils/motivation_seed_service.dart';
import 'package:solo_level_system/utils/session_reward_service.dart';
import 'package:solo_level_system/utils/stats_breakdown.dart';
import 'package:solo_level_system/utils/timer_controller.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';
import 'package:solo_level_system/widgets/common/session_loot_dialog.dart';
import 'package:solo_level_system/widgets/common/stats_period_chips.dart';
import 'package:solo_level_system/widgets/cards/rogue_challenge_modal.dart';
import 'package:solo_level_system/widgets/desktop/compact_timer_display.dart';
import 'package:solo_level_system/widgets/pomodoro/project_selector_widget.dart';

enum _PopoverTab { timer, projects, stats }

/// The macOS menu-bar popover: a small (~360x480) window showing the
/// Pomodoro timer, today's stats, and a compact project list. This is the
/// primary surface for the desktop app — the full [MainNavigationScreen] is
/// one tap away via [DesktopShellService].
///
/// Card acquisition (session-completion grants, Rogue mode's pick-a-card
/// modal) mirrors [HomeScreen]'s flow exactly, reusing the same services and
/// dialogs, so completing a session here behaves identically to the full app.
class MenuBarPopoverScreen extends StatefulWidget {
  const MenuBarPopoverScreen({super.key});

  @override
  State<MenuBarPopoverScreen> createState() => _MenuBarPopoverScreenState();
}

class _MenuBarPopoverScreenState extends State<MenuBarPopoverScreen> {
  final TimerController _timerController = TimerController();
  final BackgroundMusicService _backgroundMusicService =
      BackgroundMusicService();

  _PopoverTab _tab = _PopoverTab.timer;
  int _countCompletedToday = 0;
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  UserProgressModel? _userProgress;

  int? _pendingAfterBreakCardCount;
  int _pendingAfterBreakMinutes = 0;
  CardModel? _pendingRogueCard;
  String? _pendingRogueChallenge;

  int? _lastSessionMinutes;
  bool _completingWorkSession = false;
  bool _completingBreakSession = false;

  late int _remainingSeconds;
  late bool _isRunning;
  late bool _onBreak;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _timerController.remainingSeconds;
    _isRunning = _timerController.isRunning;
    _onBreak = _timerController.onBreak;
    _timerController.addListener(_onTimerChanged);
    SoloSyncService.instance.revision.addListener(_onSyncRevision);
    unawaited(_timerController.initialize());
    unawaited(_loadProjects());
    unawaited(_loadTodayCount());
  }

  void _onSyncRevision() {
    unawaited(_loadTodayCount());
  }

  @override
  void dispose() {
    _timerController.removeListener(_onTimerChanged);
    SoloSyncService.instance.revision.removeListener(_onSyncRevision);
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final box = Hive.box<ProjectModel>('projects');
      if (!mounted) return;
      setState(() {
        _projects = box.values.where((p) => p.isActive).toList()
          ..sort(
            (a, b) =>
                b.totalCompletedPomodoros.compareTo(a.totalCompletedPomodoros),
          );
      });
    } catch (_) {
      // Box may not be open yet (e.g. Hive still initializing) — safe to skip.
    }
  }

  Future<void> _loadTodayCount() async {
    try {
      final count = await getTodayCompletedSessions();
      if (!mounted) return;
      setState(() => _countCompletedToday = count);
    } catch (_) {}
  }

  Future<UserProgressModel> _ensureUserProgress() async {
    return _userProgress ??= await PomodoroSessionService()
        .loadOrCreateUserProgress();
  }

  void _onTimerChanged() {
    final wasRunning = _isRunning;
    final wasOnBreak = _onBreak;
    setState(() {
      _remainingSeconds = _timerController.remainingSeconds;
      _isRunning = _timerController.isRunning;
      _onBreak = _timerController.onBreak;
    });

    final justCompletedWork =
        wasRunning && !_isRunning && !_onBreak && _remainingSeconds == 0;
    final justCompletedBreak =
        wasOnBreak && !_onBreak && !_isRunning && !justCompletedWork;

    if (justCompletedWork && !_completingWorkSession) {
      _completingWorkSession = true;
      unawaited(_completeWorkSession());
    }
    if (justCompletedBreak && !_completingBreakSession) {
      _completingBreakSession = true;
      unawaited(_completeBreakSession());
    }
  }

  /// Mirrors [HomeScreen]'s `_completeWorkSessionAndOpenJournal` +
  /// `_handleFocusAcquisition`, minus the journal modal: persist the
  /// session, run the configured card-acquisition flow (immediate grant,
  /// deferred-to-break, or the Rogue pick), then resume into the break.
  Future<void> _completeWorkSession() async {
    try {
      _timerController.prepareBreakPaused();
      final settings = PomodoroSessionService.liveUserSettings();
      final minutesSpent = _timerController.workMinutes > 0
          ? _timerController.workMinutes
          : 1;
      final nextCount = _countCompletedToday + 1;

      final persistFuture = PomodoroSessionService()
          .recordCompletedSession(
            minutesSpent: minutesSpent,
            dayPomodoroNumber: nextCount,
            sessionStartTime: _timerController.sessionStartTime,
            project: _selectedProject,
            grantCardsAndPoints: false,
          )
          .then((_) {
            if (!mounted) return;
            setState(() => _countCompletedToday = nextCount);
            unawaited(_loadProjects());
          });

      if (settings.acquisitionMode == CardAcquisitionMode.rogue) {
        // Don't block the pick modal on Hive I/O.
        unawaited(persistFuture);
      } else {
        await persistFuture;
      }

      if (!mounted) return;
      await _handleFocusAcquisition(
        settings: settings,
        minutesSpent: minutesSpent,
      );

      if (mounted) setState(() => _lastSessionMinutes = minutesSpent);
      _timerController.resumePausedBreak();
    } finally {
      _completingWorkSession = false;
    }
  }

  Future<void> _handleFocusAcquisition({
    required UserSettingsModel settings,
    required int minutesSpent,
  }) async {
    final userProgress = await _ensureUserProgress();
    _pendingAfterBreakCardCount = null;
    _pendingRogueCard = null;
    _pendingRogueChallenge = null;

    switch (settings.acquisitionMode) {
      case CardAcquisitionMode.disabled:
        SessionRewardService.grant(
          minutes: minutesSpent,
          kind: SessionKind.focus,
          progress: userProgress,
          cardCountOverride: 0,
        );
        return;
      case CardAcquisitionMode.sessionCompletion:
        final count = settings.clampedSessionCardCount;
        if (settings.acquireTiming == CardAcquireTiming.afterFocus) {
          try {
            await MotivationSeedService.ensureSeeded();
            await CollectibleDeckSeedService.ensureSeeded();
          } catch (_) {}
          final loot = SessionRewardService.grant(
            minutes: minutesSpent,
            kind: SessionKind.focus,
            progress: userProgress,
            cardCountOverride: count,
          );
          if (loot.cards.isNotEmpty) {
            unawaited(
              JournalService.addCardsEarned(
                cardTitles: loot.cards.map((c) => c.title).toList(),
                source: 'focus',
                modeWire: CardAcquisitionMode.sessionCompletion.wire,
              ),
            );
            if (mounted) await showSessionLootDialog(context, loot);
          }
        } else {
          _pendingAfterBreakCardCount = count;
          _pendingAfterBreakMinutes = minutesSpent;
        }
        return;
      case CardAcquisitionMode.rogue:
        await _promptRogueChallenge(minutesSpent: minutesSpent);
        return;
    }
  }

  Future<void> _promptRogueChallenge({required int minutesSpent}) async {
    if (!mounted) return;
    final settings = PomodoroSessionService.liveUserSettings();
    final challenges = RogueChallengeDefaults.normalize(
      settings.rogueChallengeList,
      includeDev: AppEnvironment.isTest,
    );
    var drawn = SessionRewardService.drawCards(2, kind: SessionKind.focus);
    if (drawn.length < 2) {
      try {
        await MotivationSeedService.ensureSeeded();
        await CollectibleDeckSeedService.ensureSeeded();
      } catch (_) {}
      drawn = SessionRewardService.drawCards(2, kind: SessionKind.focus);
    }
    final options = buildRogueOptions(cards: drawn, challenges: challenges);
    if (options.length < 2) {
      if (mounted) {
        showAppSnack(
          context,
          text: 'Need more cards/challenges for Rogue mode',
        );
      }
      return;
    }
    final userProgress = await _ensureUserProgress();
    if (!mounted) return;
    final pick = await showRogueChallengeModal(
      context: context,
      options: options,
      userProgress: userProgress,
    );
    if (!mounted || pick == null) return;
    _pendingRogueCard = pick.card;
    _pendingRogueChallenge = pick.challenge;
    _pendingAfterBreakMinutes = minutesSpent;
    unawaited(
      JournalService.addRogueChallengeSelected(
        challenge: pick.challenge,
        cardTitle: pick.card.title,
        cardId: pick.card.id,
        source: 'focus',
      ),
    );
  }

  /// Mirrors [HomeScreen]'s `_onBreakSessionCompleted`: grants whatever was
  /// deferred from the focus session (Rogue pick or after-break card count).
  Future<void> _completeBreakSession() async {
    try {
      final userProgress = await _ensureUserProgress();
      SessionLoot? loot;
      String? modeWireForLog;
      String? rogueChallengeForLog;

      if (_pendingRogueCard != null) {
        rogueChallengeForLog = _pendingRogueChallenge;
        modeWireForLog = CardAcquisitionMode.rogue.wire;
        loot = SessionRewardService.grantDrawnCards(
          minutes: _pendingAfterBreakMinutes > 0
              ? _pendingAfterBreakMinutes
              : (_timerController.breakMinutes > 0
                    ? _timerController.breakMinutes
                    : 5),
          kind: SessionKind.focus,
          cards: [_pendingRogueCard!],
          progress: userProgress,
        );
      } else if (_pendingAfterBreakCardCount != null) {
        modeWireForLog = CardAcquisitionMode.sessionCompletion.wire;
        loot = SessionRewardService.grant(
          minutes: _pendingAfterBreakMinutes > 0
              ? _pendingAfterBreakMinutes
              : (_timerController.workMinutes > 0
                    ? _timerController.workMinutes
                    : 1),
          kind: SessionKind.focus,
          progress: userProgress,
          cardCountOverride: _pendingAfterBreakCardCount,
        );
      }

      _pendingRogueCard = null;
      _pendingRogueChallenge = null;
      _pendingAfterBreakCardCount = null;
      _pendingAfterBreakMinutes = 0;

      if (loot != null && loot.cards.isNotEmpty) {
        unawaited(
          JournalService.addCardsEarned(
            cardTitles: loot.cards.map((c) => c.title).toList(),
            source: 'focus',
            modeWire: modeWireForLog,
            rogueChallenge: rogueChallengeForLog,
          ),
        );
        if (mounted) await showSessionLootDialog(context, loot);
      }
    } finally {
      _completingBreakSession = false;
    }
  }

  void _startPause() {
    if (_isRunning) {
      _timerController.pauseTimer();
      return;
    }
    if (_selectedProject != null) {
      _timerController.updateDurations(
        _selectedProject!.workDurationMinutes,
        _selectedProject!.breakDurationMinutes,
      );
    }
    setState(() => _lastSessionMinutes = null);
    _timerController.startTimer();
  }

  void _stop() {
    _timerController.resetTimer();
    setState(() => _lastSessionMinutes = null);
  }

  void _selectProject(ProjectModel? project) {
    setState(() {
      _selectedProject = project;
      _tab = _PopoverTab.timer;
    });
    if (!_isRunning) {
      final work = project?.workDurationMinutes ?? 25;
      final brk = project?.breakDurationMinutes ?? 5;
      _timerController.updateDurations(work, brk);
    }
  }

  /// Same mute entry point HomeScreen's system-notification action uses —
  /// it already toggles `allowMusic`, pauses/resumes the lofi player, and
  /// notifies listeners, so the popover picks the change up for free.
  void _toggleMusic() => _timerController.toggleMute();

  /// Picks a new random track. No room concept exists on this surface (room
  /// selection is ephemeral HomeScreen state, never persisted — see
  /// HomeScreen._playLofi()), so this always takes the same unrestricted
  /// path HomeScreen itself falls back to whenever no room is selected.
  void _shuffleTrack() {
    if (!_timerController.allowMusic) return;
    unawaited(
      _backgroundMusicService.playRandomTrack().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  Widget _buildMusicRow() {
    final muted = !_timerController.allowMusic;
    final label = muted
        ? 'Music muted'
        : (_timerController.getCurrentTrackTitle() ?? '—');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BareIconButton(
          icon: muted ? Icons.volume_off : Icons.music_note,
          tooltip: muted ? 'Unmute' : 'Mute',
          onTap: _toggleMusic,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _BareIconButton(
          icon: Icons.shuffle,
          tooltip: 'New track',
          onTap: muted ? null : _shuffleTrack,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorPalette.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case _PopoverTab.timer:
        return _buildTimerTab();
      case _PopoverTab.projects:
        return _buildProjectsTab();
      case _PopoverTab.stats:
        return _buildStatsTab();
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          _IconGhostButton(
            icon: Icons.open_in_full,
            tooltip: 'Open Full App',
            onTap: () => DesktopShellService().openFullApp(),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildTabBar()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        _buildTabChip(
          _PopoverTab.timer,
          Icons.timer_outlined,
          Icons.timer,
          'Timer',
        ),
        const SizedBox(width: 8),
        _buildTabChip(
          _PopoverTab.projects,
          Icons.folder_outlined,
          Icons.folder,
          'Projects',
        ),
        const SizedBox(width: 8),
        _buildTabChip(
          _PopoverTab.stats,
          Icons.bar_chart_outlined,
          Icons.bar_chart,
          'Stats',
        ),
      ],
    );
  }

  Widget _buildTabChip(
    _PopoverTab tab,
    IconData icon,
    IconData selectedIcon,
    String tooltip,
  ) {
    final selected = _tab == tab;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColorPalette.primary
                  : AppColorPalette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              size: 18,
              color: selected
                  ? AppColorPalette.white
                  : AppColorPalette.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerTab() {
    final pomodorosBox = Hive.isBoxOpen('pomodoros')
        ? Hive.box<PomodoroModel>('pomodoros')
        : null;
    final streak = computeStreakStats(
      period: StatsPeriod.week,
      activityTimes: pomodorosBox?.values.map((s) => s.startTime) ?? const [],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppUiSizes.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          return Column(
            children: [
              // Same widget the full app uses above the timer: shows the
              // project chips + selected project's progress (e.g. "3/5"),
              // and — matching mobile — hides itself while a session is
              // actively running to avoid mid-session project switches.
              ProjectSelectorWidget(
                projects: _projects,
                selectedProject: _selectedProject,
                isRunning: _isRunning,
                selectedExpandedWidth: side,
                onProjectSelected: _selectProject,
              ),
              SizedBox(
                width: side,
                height: side,
                child: CompactTimerDisplay(
                  formattedTime: _timerController.formatTime(_remainingSeconds),
                  isRunning: _isRunning,
                  onBreak: _onBreak,
                  completedSessions: _countCompletedToday,
                  albumImagePath:
                      _backgroundMusicService.currentTrack?.albumImagePath,
                  onToggle: _startPause,
                  onReset: _stop,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: AppColorPalette.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${streak.current} · $_countCompletedToday',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColorPalette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildMusicRow(),
              if (_lastSessionMinutes != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColorPalette.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColorPalette.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_lastSessionMinutes min',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColorPalette.textColor,
                          ),
                        ),
                      ),
                      _IconGhostButton(
                        icon: Icons.menu_book_outlined,
                        tooltip: 'Open Journal',
                        onTap: () => DesktopShellService().openFullApp(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 22,
              color: AppColorPalette.grey400,
            ),
            const SizedBox(height: 6),
            Text(
              'No projects yet',
              style: TextStyle(
                fontSize: 12,
                color: AppColorPalette.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppUiSizes.lg),
      itemCount: _projects.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColorPalette.grey300),
      itemBuilder: (context, index) {
        final project = _projects[index];
        final isSelected = _selectedProject?.id == project.id;
        return InkWell(
          onTap: () => _selectProject(isSelected ? null : project),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: isSelected
                      ? AppColorPalette.primary
                      : AppColorPalette.grey400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: AppColorPalette.textColor,
                    ),
                  ),
                ),
                Text(
                  '${project.totalCompletedPomodoros}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColorPalette.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    final pomodorosBox = Hive.isBoxOpen('pomodoros')
        ? Hive.box<PomodoroModel>('pomodoros')
        : null;
    final sessions = pomodorosBox?.values.toList() ?? const <PomodoroModel>[];
    final now = DateTime.now();
    final todaySessions = sessions.where(
      (s) =>
          s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day,
    );
    final todayMinutes = todaySessions.fold<int>(
      0,
      (sum, s) => sum + s.minutesSpent,
    );
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.minutesSpent,
    );
    final dayStreak = computeStreakStats(
      period: StatsPeriod.week,
      activityTimes: sessions.map((s) => s.startTime),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppUiSizes.lg,
        AppUiSizes.xs,
        AppUiSizes.lg,
        AppUiSizes.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle_outline,
                  value: '$_countCompletedToday',
                  label: 'today',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule,
                  value: '${todayMinutes}m',
                  label: 'today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department,
                  value: '${dayStreak.current}',
                  label: 'streak',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.all_inclusive,
                  value: '$totalMinutes',
                  label: 'min total',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Last 7 days',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColorPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _WeekBars(sessions: sessions, now: now),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColorPalette.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColorPalette.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColorPalette.textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColorPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  final List<PomodoroModel> sessions;
  final DateTime now;

  const _WeekBars({required this.sessions, required this.now});

  @override
  Widget build(BuildContext context) {
    final counts = List<int>.filled(7, 0);
    final startOfToday = DateTime(now.year, now.month, now.day);
    for (final s in sessions) {
      final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final diff = startOfToday.difference(d).inDays;
      if (diff >= 0 && diff < 7) {
        counts[6 - diff]++;
      }
    }
    final maxCount = counts.fold<int>(1, (m, c) => c > m ? c : m);

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message: '${counts[i]}',
                child: FractionallySizedBox(
                  heightFactor: counts[i] / maxCount,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 4),
                    decoration: BoxDecoration(
                      color: counts[i] == 0
                          ? AppColorPalette.grey300
                          : AppColorPalette.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconGhostButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconGhostButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColorPalette.primary.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 15, color: AppColorPalette.primary),
          ),
        ),
      ),
    );
  }
}

/// A bare tappable icon — no background, no border, just the glyph (plus
/// the platform's default tap/hover feedback). Used for the compact music
/// row where a visible button chrome would be too heavy for the space.
class _BareIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _BareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Icon(
          icon,
          size: 14,
          color: enabled
              ? AppColorPalette.textSecondary
              : AppColorPalette.grey400,
        ),
      ),
    );
  }
}
