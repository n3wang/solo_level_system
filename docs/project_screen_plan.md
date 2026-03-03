# Project Screen Redesign Plan

This plan defines the new Project screen behavior and UI based on the provided mock and requirements.

## Goal

Build a Project screen that:

- Uses a layout and interaction style similar to `RoomManagementScreen`
- Supports richer scheduling controls (targets, active day states, time windows)
- Adds random and no-project quick selection behaviors
- Adds a visual work/break breakdown indicator
- Keeps the floating entry button unshadowed and visible only when no session is running
- Replaces bottom navigation access to Project screen with Home-screen entry only
- Supports active/archived project management in one place

## UX And Styling Direction

- Reuse the Room Management visual language:
  - card layout blocks
  - compact icon controls
  - rectangle indicators
  - clean, low-shadow style
- Keep the project entry FAB unshadowed when timer is not running
- Remove direct Project tab entry from bottom navigator
- Use Home as the only entry point to project management (same as room-management access pattern)
- Place controls in grouped sections matching the mock:
  - Project selector
  - Session targets
  - Active days
  - Work hour settings
  - Session durations + breakdown
- Add a top-left flat toggle button to switch current list mode:
  - `Active`
  - `Archived`

## Functional Requirements

## 0) Navigation And Existing Screen Consolidation

- There is already an existing project management screen.
- Implementation decision:
  - Reuse existing `projects_management_screen.dart` as base if practical, but align it to this new layout/flow.
  - Remove old entry points that conflict with this plan.
- Bottom navigator:
  - Remove/hide Project screen tab access.
  - Route users to project management from Home only.
- Home screen:
  - Keep/add unshadowed floating button (visible only when timer is not running).
  - Tapping opens the redesigned Project screen.

## 1) Default Session Targets

- New project defaults:
  - `dailySessionTarget = 1`
  - `weeklySessionTarget = 2`
- Targets are editable from Project screen.

## 2) Active Days With Multi-State Rectangles

- Show 7 day rectangles (Mon first, then Tue ... Sun).
- Default for new project: all days set to `active`.
- Tap cycle for each day:
  1. `active` (full rectangle)
  2. `inactive` (blank)
  3. `morning_only` (top segment filled)
  4. `midday_only` (middle segment filled)
  5. `night_only` (bottom segment filled)
  6. back to `active`
- Right-side helper text must show day labels and selected state in plain text for clarity.

## 3) Work Hour Settings (24h)

- Add editable start times for:
  - Morning start
  - Afternoon start
  - Evening start
- Use `HH:mm` 24-hour format.
- Provide default values for new projects (proposal):
  - Morning: `09:00`
  - Afternoon: `13:00`
  - Evening: `18:30`
- Validate ordering: `morning < afternoon < evening`.

## 4) Right-Side Scheduling Checkboxes

- Add three options:
  - `Send notification`
  - `Show project as selectable chip only within 1 hour of target window`
  - `Do not score project if outside configured hour range`
- Persist each toggle per project.

## 5) Session Duration Controls

- Keep editable `workDurationMinutes` and `breakDurationMinutes`.
- Add plus/minus quick actions in steps of 5 minutes.
- Minimum/maximum guard rails:
  - Work: `5..180`
  - Break: `5..60`

## 6) Work/Break Breakdown (replacing volume-style bars)

- Display colored rectangles:
  - Red count = `ceil(workMinutes / 5)`
  - Green count = `ceil(breakMinutes / 5)`
- Example:
  - Work 25, Break 5 -> `5 red + 1 green`
- Recompute instantly when duration values change.

## 7) Project Selection Behavior

- First item in selector is always `No Project`.
- Add quick icon buttons:
  - Go to `No Project`
  - Pick `Random Project` (must choose from real projects only, never `No Project`)
- Exit behavior:
  - If a project is selected, keep it selected when closing the project management view.
  - If no project selected, return as `No Project`.

## 8) Archive Controls And Visibility Filter

- Add an `Archive Project` action for the currently selected project.
- Archive behavior:
  - marks project as archived (soft archive, not delete)
  - archived projects are excluded from active selection chips by default
  - if archived project is currently selected, switch selection to `No Project` or previous valid active selection
- Add top-left flat filter button:
  - label reflects current mode: `Active` or `Archived`
  - tapping toggles list mode
  - list content and selector cards reflect chosen mode
- In `Archived` mode:
  - allow viewing/editing metadata
  - allow `Unarchive` action
  - prevent archived project from being selected for active pomodoro runs unless explicitly unarchived

## 9) Create Project Modal

- Add a create icon/button that opens modal form.
- Modal fields:
  - Title
  - Description
  - Phrases (one per line)
- Save creates project and immediately selects it.

## Data Model Changes

Extend `ProjectModel` with new persisted fields:

- `Map<int, String> activeDayStates`
  - keys: `1..7` (Mon..Sun)
  - values: `active | inactive | morning_only | midday_only | night_only`
- `String morningStartTime` (`HH:mm`)
- `String afternoonStartTime` (`HH:mm`)
- `String eveningStartTime` (`HH:mm`)
- `bool sendTimeNotification`
- `bool showChipOnlyWithinOneHour`
- `bool dontScoreOutsideHourRange`
- `List<String> phrases` (if phrases should be project-owned; otherwise keep in room config and map by project id)
- `DateTime? archivedAt` (already available, keep as source of truth for archive state)

Migration notes:

- For old projects, backfill defaults safely.
- Preserve existing `activeDays` for compatibility until migration fully adopted.
- If both old and new fields exist, new fields become source of truth.

## Screen/Component Plan

Primary files expected to change:

- `lib/screens/projects_management_screen.dart`
- `lib/widgets/pomodoro/project_selector_widget.dart`
- `lib/screens/home_screen.dart` (selection/routing and scoring gates)
- `lib/models/project_model.dart` (+ adapter regeneration)
- `lib/screens/main_navigation_screen.dart` (remove/disable project tab entry)

Potential new widgets:

- `project_day_state_strip.dart` (7 rectangles + state text)
- `project_hour_window_editor.dart` (HH:mm rows)
- `project_breakdown_bars.dart` (red/green segments)
- `project_archive_toggle_button.dart` (top-left Active/Archived flat toggle)
- `project_archive_action_button.dart` (archive/unarchive control)

## Behavior Logic Plan

## Day State Scoring Rule

Project is eligible today when:

- Day state is not `inactive`, and
- Current time falls into state window:
  - `active`: any time
  - `morning_only`: `>= morningStart && < afternoonStart`
  - `midday_only`: `>= afternoonStart && < eveningStart`
  - `night_only`: `>= eveningStart`

If `dontScoreOutsideHourRange` is true and project not eligible, no score/xp update for that session.

## Selectable Chip Visibility Rule

If `showChipOnlyWithinOneHour` is true, show project chip only when current time is within 1 hour of valid window start.

## Implementation Phases

## Phase 1 - Data And Migration

- Add new fields to `ProjectModel`.
- Update Hive adapter and migration defaults.
- Add helper methods for:
  - parsing `HH:mm`
  - current window checks
  - day state cycle

## Phase 2 - UI Skeleton

- Build sections and controls per mock.
- Add create modal.
- Add random/no-project quick actions.
- Add breakdown bars.
- Add Active/Archived top-left flat toggle.
- Add archive/unarchive action button.

## Phase 3 - Behavior Wiring

- Connect selection and exit behavior.
- Wire scoring gating based on day/time settings.
- Wire chip visibility rules.
- Ensure timer durations update immediately from project settings.
- Remove bottom-nav project entry and verify Home-only entry flow.
- Handle selection fallback when currently selected project is archived.

## Phase 4 - QA And Polish

- Responsive checks for narrow and wide screens.
- Accessibility labels for rectangle states and icon buttons.
- Empty-state and validation messaging.

## Test Checklist

- New project defaults to daily 1 / weekly 2.
- Day tap cycles through all 5 states correctly.
- Monday is first rectangle; text legend matches all days.
- HH:mm validation blocks invalid or unordered windows.
- Checkbox rules persist across restart.
- Plus/minus duration controls move in 5-minute steps only.
- Breakdown bars match formula for multiple duration pairs.
- Random never returns `No Project`.
- No-project icon always selects `No Project`.
- Exiting screen keeps the currently selected project.
- Scoring blocked when outside hour range if toggle is enabled.
- Bottom navigator no longer opens Project screen.
- Home FAB opens Project screen only when timer is not running.
- Archive action moves project from Active list to Archived list.
- Top-left flat toggle switches list mode correctly.
- Unarchive returns project to Active list and makes it selectable.

## Open Questions To Confirm Before Build

- Should phrases live in `ProjectModel` directly, or stay in `roomManagement` keyed by project id?. > Stays in the room Managemnet
- Exact default hour windows (`09:00/13:00/18:30`) acceptable? > Yes
- Should random selection be re-roll each tap or persist until changed? > Yes reroll, for project manager and room amangement and exclude the current card if possible and the no project / No room selected. Do not show reroll if only is active card and no other project/card 
- When archiving selected project, should app always fall back to `No Project`, or nearest active project? > Yes always to nearest project
- The buttons in projects (random rolls, No project, create ) should be copying the design oinRoom management, meaning they overlay the cards, and works well. 