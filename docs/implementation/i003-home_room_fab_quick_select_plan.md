# Home Room FAB Quick Select Plan

This document defines the interaction and implementation plan for upgrading the room FAB behavior on `HomeScreen`.

## Purpose

- Make room selection faster from Home without leaving the timer screen.
- Keep full room editing in `RoomManagementScreen`, but behind an intentional double-tap gesture.
- Provide visual room shortcuts using each room's main image.

## Entry Points

- `HomeScreen` floating action button area (`room-management-fab`).

## UX Summary

- Single tap on room FAB:
  - opens a quick room picker rail that slides to the right.
  - shows up to 5 room icon buttons.
  - tap a room icon to set that room as active in Home.
- Double tap on room FAB:
  - opens `RoomManagementScreen`.
- Quick picker content:
  - only active rooms.
  - max 5 icons (most relevant first).
  - each icon image is the room's main visual representation.

## Interaction Rules

1. **Single tap** toggles quick picker open/close.
   1. tapping again on the original room management icon should go to the room editor screen
2. **Double tap** opens Room Management directly.
3. If picker is open and user taps outside, picker closes.
4. Selecting a room from picker:
   - sets `selectedRoom`,
   - reloads room phrases/visual context,
   - closes picker.
5. If selected room is already active and tapped again:
   - keep selected room unchanged,
   - close picker.

## Room Image Source Rules

For each quick-picker icon, use this priority:

1. `room.iconAssetPath` (if valid)
2. first visual from room config (`roomManagement[selectedRoomId].selectedVisuals.first`)
3. known seeded room fallback icons (space/mansion)
4. generic room icon (`Icons.meeting_room_outlined`)

Image fitting:

- Use `BoxFit.cover`.
- Clip with rounded corners (circle or rounded square).
- Keep aspect-correct crop (no distortion).

## State Model

Add Home-screen local state:

- `bool _isRoomQuickPickerOpen`
- `DateTime? _lastRoomFabTapAt`
- `Timer? _roomFabSingleTapTimer` (if using delayed single-tap confirmation)
- `List<RoomModel> _quickPickerRooms` (derived from active rooms, max 5)

Recommended gesture strategy:

- Use explicit double-tap detection with a short threshold (e.g. 260ms).
- Delay single-tap action slightly so double-tap can override.

Pseudo-flow:

1. First tap:
   - start short timer for single-tap action.
2. Second tap before threshold:
   - cancel pending single-tap timer,
   - open Room Management.
3. No second tap:
   - execute single-tap action (toggle quick picker).

## Animation Plan

Quick picker reveal:

- Slide + fade in from FAB origin to the right.
- Stagger icons (`40-60ms` each) for clarity.
- Duration: `220-280ms`.
- Curve: `Curves.easeOutCubic`.

Quick picker hide:

- Reverse stagger or quick fade/slide collapse (`160-220ms`).

Icon tap feedback:

- subtle scale down/up (`0.96 -> 1.0`) and highlight ring on selected room.

## Layout Plan

- Keep existing two small FABs (project + room) unless future redesign says otherwise.
- Room quick picker anchored near room FAB.
- Horizontal row, up to 5 icons:
  - icon size: `36-42`
  - spacing: `8`
  - selected border: primary color
  - unselected border: soft neutral

## Files Expected To Change

- `lib/screens/home_screen.dart` (primary implementation)
- optional helper extraction:
  - `lib/widgets/pomodoro/room_quick_picker_widget.dart`

## Persistence / Data Notes

- No new persistence needed.
- Reuse existing room + roomManagement data:
  - `rooms` list for active rooms
  - `roomManagement` box for room visuals/phrases

## Edge Cases

- No active rooms: single tap should do nothing (or show tiny hint).
- More than 5 active rooms:
  - show first 5 by current ordering (future: most recent/priority).
- Missing/corrupt image path:
  - fallback to next source; never crash.
- Rapid repeated taps:
  - prevent duplicate route push to Room Management.
- If timer running:
  - quick picker should still be usable unless explicitly blocked by UX decision.

## Test Checklist

- [ ] Single tap opens/closes quick picker.
- [ ] Double tap opens Room Management (without flickering picker open first).
- [ ] Picker shows max 5 active rooms.
- [ ] Room icon image uses correct source priority.
- [ ] Tapping icon sets selected room immediately in Home.
- [ ] Picker closes after room selection.
- [ ] Selected room indicator updates correctly.
- [ ] Missing images fall back gracefully.
- [ ] No duplicate navigation pushes on rapid taps.
- [ ] Works on narrow mobile width and larger web width.

## Non-Goals

- Replacing full Room Management editing with quick picker.
- Adding room creation/editing inside quick picker.
- Reordering rooms from Home quick picker.

## Open Questions

- For >5 rooms, should the 5 shown be first in list or include current selected room always?
- Should quick picker auto-close after a timeout (e.g. 3-4 seconds)?
- Should quick picker be disabled while timer is actively running?
