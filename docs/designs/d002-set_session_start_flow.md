# Set Session Start Flow

Design for starting a workout session from the currently selected set on the **Sets** tab (e.g. Set 2 — Lower Body Gym).

## Goal

- Keep **+ New Exercise** for editing the set.
- Add a second FAB to **start a session** for the selected set.
- Before lifting: show a **pre-session summary** of what will be done.
- Then run exercises **one by one**.
- End with the existing post-workout summary.

## Flow overview

```text
[Sets tab — Set 2 selected]
        │
        │  tap "Start Set 2" FAB
        ▼
[1. Pre-session summary]
        │
        │  tap "Begin Workout"
        ▼
[2. Exercise 1 of N] ──Next──► [3. Exercise 2 of N] ──…──► [N. Last exercise]
        │                                                         │
        │              (or Skip / finish early)                    │
        ▼                                                         ▼
[4. Post-workout summary] ◄───────────────────────────────────────┘
        │
        ▼
[Back to Sets tab]
```

---

## Screen 0 — Entry: Sets tab (existing + new FAB)

**Source:** `WorkoutScreen` Sets tab, currently selected set (example: Set **2** / Lower Body Gym).

```text
┌─────────────────────────────────────┐
│  Sets          Programs             │
├─────────────────────────────────────┤
│  [A] [1] [2] [3] [4] [5]   ☰  🔍   │  ← Set 2 active
│                                     │
│  Lower Body Gym                     │
│  Last performed: Never performed    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🖼 back squat      3x 10kg  │    │
│  │ Never performed             │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🖼 Deadlift…       3x 10kg  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🖼 front squat     3x 10kg  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🖼 Leg press       3x 10kg  │    │
│  └─────────────────────────────┘    │
│                                     │
│              ┌──────────────┐       │
│              │ ▶ Start Set 2│  ← NEW│
│              └──────────────┘       │
│              ┌──────────────┐       │
│              │ + New Exercise│      │  (existing)
│              └──────────────┘       │
└─────────────────────────────────────┘
```

### FAB rules

| FAB | When shown | Action |
|-----|------------|--------|
| **Start Set N** | Sets tab, a set is selected, set has ≥1 exercise | Open pre-session summary for that set |
| **+ New Exercise** | Sets tab (unchanged) | Create / add exercise to current set |

- Label uses the selected set number/letter: `Start Set 2`, `Start Set A`, etc.
- Disabled / hidden if the set has no exercises (optional snackbar: “Add an exercise first”).
- Stack FABs vertically (Start above New Exercise), matching existing extended FAB style.
- Distinct `heroTag`s to avoid Flutter FAB hero conflicts.

---

## Screen 1 — Pre-session summary (new)

Confirm what the session will include before the timer starts.

```text
┌─────────────────────────────────────┐
│  ←  Ready to start                  │
├─────────────────────────────────────┤
│                                     │
│  SET 2                              │
│  Lower Body Gym                     │
│                                     │
│  4 exercises · ~12 sets             │
│  Est. 35–45 min                     │
│                                     │
│  ── Today's plan ─────────────────  │
│                                     │
│  1. back squat                      │
│     3 sets · 10 kg · quads/glutes   │
│                                     │
│  2. Deadlift conventional           │
│     3 sets · 10 kg · posterior      │
│                                     │
│  3. front squat                     │
│     3 sets · 10 kg · quads          │
│                                     │
│  4. Leg press                       │
│     3 sets · 10 kg · legs           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │      ▶ Begin Workout        │    │
│  └─────────────────────────────┘    │
│                                     │
│        Cancel                       │
└─────────────────────────────────────┘
```

### Contents

- Set identity: number/letter + name (e.g. Set 2 · Lower Body Gym).
- Totals: exercise count, planned set count, rough duration (optional).
- Ordered list of exercises with planned volume (from last workout / defaults, same rules as active session).
- Primary CTA: **Begin Workout**.
- Secondary: **Cancel** → back to Sets tab (no session created).

### Session creation

On **Begin Workout**:

1. Create `WorkoutSessionModel` with set name as `routineName` (and set id if useful).
2. Load ordered exercises for the selected set.
3. Push active workout at exercise index `0`.

---

## Screen 2..N — Workout one exercise at a time

Focus on a single exercise per screen; advance explicitly.

```text
┌─────────────────────────────────────┐
│  Set 2 · Lower Body Gym      12:34  │
│  Exercise 1 of 4                    │
├─────────────────────────────────────┤
│                                     │
│  ████░░░░  Progress                 │  ← exercise progress
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🖼  back squat              │    │
│  │ Compound lower body…        │    │
│  └─────────────────────────────┘    │
│                                     │
│  Set │ Reps │ Weight │ ✓            │
│  1   │ 10   │ 10 kg  │ ☐            │
│  2   │ 10   │ 10 kg  │ ☐            │
│  3   │ 10   │ 10 kg  │ ☐            │
│                                     │
│  [Rest timer appears after a set]   │
│                                     │
│  ┌──────────┐      ┌─────────────┐  │
│  │  Skip    │      │ Next →      │  │
│  └──────────┘      └─────────────┘  │
└─────────────────────────────────────┘
```

### Behavior

| Control | Behavior |
|---------|----------|
| Check set ✓ | Mark set complete; start rest timer (existing behavior) |
| **Next →** | Move to next exercise (prefer when all sets for this exercise are done; allow early advance) |
| **Skip** | Skip current exercise; go to next (or finish if last) |
| Last exercise + Next / Finish | Go to post-workout summary |
| Back / End session | Confirm → save partial → post-workout summary |

### Notes vs current active session

- Today `ActiveWorkoutSessionScreen` uses a **tab bar** across all exercises.
- For this set-start flow, prefer **one exercise per screen** with Next/Skip (tabs optional as secondary navigation).
- Reuse the same set logging, rest timer, last-workout defaults, and save path where possible.

### Example sequence (Set 2)

1. **back squat** → Next  
2. **Deadlift conventional** → Next  
3. **front squat** → Next  
4. **Leg press** → Finish  

---

## Screen End — Post-workout summary (existing)

Reuse `WorkoutSummaryScreen` after the session ends (complete or saved early).

```text
┌─────────────────────────────────────┐
│  ✕  Workout Complete!               │
├─────────────────────────────────────┤
│                                     │
│         🎉 Great Job!               │
│   You completed your workout        │
│                                     │
│  Routine: Lower Body Gym            │
│  Duration: 42 min                   │
│  Sets: 12 / 12                      │
│                                     │
│  ┌─────────────────────────────┐    │
│  │         Done                │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

Done → return to Sets tab (selected set unchanged).

---

## Edge cases

| Case | Handling |
|------|----------|
| Empty set | Hide or disable Start FAB; snackbar if tapped |
| Mid-session return | If an active session exists for this set, Start FAB becomes **Resume** and jumps to current exercise |
| App kill mid-session | Same persistence rules as existing active session (if any) |
| Reorder / edit set while summary open | Summary is a snapshot at open time; Begin uses that snapshot |

---

## Implementation sketch (later)

1. `WorkoutScreen`: dual FAB when Sets tab + set selected.
2. New screen (or bottom sheet): `SetSessionSummaryScreen` — pre-session plan.
3. Start session → `ActiveWorkoutSessionScreen` (or thin wrapper) in **sequential** mode: one exercise, Next/Skip.
4. Finish → existing `WorkoutSummaryScreen`.

### Suggested files

| Piece | Likely touch |
|-------|----------------|
| Entry FABs | `lib/screens/workout_screen.dart` |
| Pre-summary | new `lib/screens/set_session_summary_screen.dart` |
| One-by-one workout | `lib/screens/active_workout_session_screen.dart` (sequential mode) or new wrapper |
| Post-summary | `lib/screens/workout_summary_screen.dart` (reuse) |

---

## Acceptance checklist

- [ ] Sets tab shows **Start Set N** alongside **+ New Exercise** for the selected set.
- [ ] Start opens pre-session summary with ordered exercises and planned volume.
- [ ] Begin creates a session and shows exercise 1 of N.
- [ ] User advances one exercise at a time until done.
- [ ] Finish lands on post-workout summary, then back to Sets.
