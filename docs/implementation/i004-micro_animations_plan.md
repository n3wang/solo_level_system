# Micro Animations Plan

This plan defines subtle, high-value animations to make the app feel more alive without becoming distracting.

## Purpose

- Add small motion cues that improve clarity and feedback.
- Prioritize Pomodoro interactions first (timer urgency + music changes).
- Keep motion lightweight, accessible, and consistent with current UI style.

## Entry Points

- `HomeScreen` timer area (main Pomodoro square + timer text).
- `CompactMusicWidget` / music panel interactions.
- Project/Room selector chips and card state transitions.

## UI Sections / Components

### 1) Timer Urgency Animation (last 30 seconds)

- Target: timer text in Home Pomodoro square.
- Trigger: when remaining time is `<= 30s` and timer is running.
- Motion style:
  - Very small horizontal shake (`x: -2..+2 px`) every second tick.
  - Optional tiny pulse (`scale: 1.0 -> 1.02 -> 1.0`) paired with shake.
- Cadence:
  - `30s..11s`: gentle shake once per second.
  - `10s..1s`: slightly stronger/faster shake.
- Stop conditions:
  - Timer paused, reset, completed, or app moved off timer screen.

### 2) Music Change Feedback Animation

- Target: music box container and/or track title row.
- Trigger: when user taps “change track” or auto-switches to next track.
- Motion style (choose one final variant during implementation):
  - Quick “nudge” shake (`x: -3..+3 px`, 220-300ms), or
  - Small bounce (`scale: 1.0 -> 1.03 -> 1.0`, 260ms).
- Optional enhancement:
  - Brief highlight flash on title/subtitle opacity.

### 3) Selector Micro Animations (already partially present)

- Keep selected chip expansion and color transition.
- Add small deselect transition symmetry for polish.
- Ensure archived/active list switches keep consistent easing curves.

### 4) Nice-to-have Future Animations

- Room/Project card “selected” glow fade-in (very subtle).
- Counter +/- press feedback with tiny scale tap animation.
- Tracks/Visuals expand-collapse with animated size + opacity.

## Interaction Rules

- Motion should communicate state, not decorate randomly.
- One primary animation at a time in the same component.
- No long loops except intentional urgency (timer last 30 seconds).
- Keep all micro animations under `500ms` unless tied to timer ticking.

## State Model + Persistence

- No persistence required for animation state itself.
- Add optional user setting later:
  - `reduceMotion` boolean in user settings.
- If `reduceMotion == true`:
  - disable shake effects,
  - keep only opacity/color changes with short duration.

## Accessibility and Performance Constraints

- Respect platform/system reduce-motion settings where feasible.
- Avoid expensive rebuilds:
  - prefer `AnimationController`, `AnimatedBuilder`, or local implicit animations.
  - avoid repainting large parent trees.
- Keep transforms on small widgets (text row/container), not whole pages.

## Suggested Technical Approach

- Use Flutter built-in animation APIs first (no dependency required):
  - `AnimatedContainer`, `AnimatedScale`, `TweenAnimationBuilder`, `SlideTransition`, `Transform.translate`.
- Add a shared helper for consistent curves/durations:
  - Example: `lib/widgets/common/micro_animations.dart`.
- Define shared tokens:
  - duration short: `180-240ms`
  - duration medium: `260-360ms`
  - curve default: `Curves.easeOutCubic`

## Implementation Phases

### Phase 1 - Timer Urgency (High Priority)

- Add last-30s timer text shake with clear stop conditions.
- Validate that timer text remains readable and non-jarring.

### Phase 2 - Music Change Feedback (High Priority)

- Add small shake/bounce when track changes.
- Ensure no overlap with other heavy transitions.

### Phase 3 - Selector/Controls Polish (Medium Priority)

- Normalize chip transition timings across project/room selectors.
- Add small tap feedback to +/- controls if still needed.

### Phase 4 - Optional Settings + Reduce Motion (Medium Priority)

- Add `reduceMotion` setting and wire it to animation guards.

## Files Expected To Change

- `lib/screens/home_screen.dart`
- `lib/widgets/pomodoro/compact_music_widget.dart`
- `lib/widgets/pomodoro/project_selector_widget.dart`
- `lib/widgets/common/` (new shared micro animation helpers)
- `lib/models/user_settings_model.dart` (optional reduce-motion setting)

## Test Checklist

- [ ] Timer shake starts exactly at 30s and stops at 0/reset/pause.
- [ ] Last 10s urgency feels stronger but still readable.
- [ ] Music box animation plays on track change (manual + auto).
- [ ] Animations do not trigger layout jumps or overflow.
- [ ] No noticeable FPS drops on web/mobile.
- [ ] Animations are subtle in both light/dark themes.
- [ ] Behavior is acceptable with rapid user interactions.
- [ ] Reduce-motion mode disables shake effects (if implemented).

## Non-Goals

- Full screen transitions or heavy motion redesign.
- Long decorative animations unrelated to user actions.
- Adding third-party animation packages unless built-ins are insufficient.

## Open Questions

- Should timer urgency also include color shift in last 10 seconds?
- For music change, prefer shake, bounce, or only title flash?
- Should reduce-motion default to `on` or `off` for existing users?
