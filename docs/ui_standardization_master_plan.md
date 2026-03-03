# UI Standardization Master Plan

This document defines the implementation plan to make the app visually consistent (fonts, colors, spacing, components, interaction patterns), and also standardize how UI decisions are documented in markdown.

## Why This Plan

There are already useful docs:

- `docs/theme_system_guide.md`
- `docs/PALETTE_SYSTEM_GUIDE.md`
- `docs/color_palette_guide.md`

But there is no single execution plan tying those rules to:

- concrete code migration phases
- component-level standards
- markdown standards for documenting screens/features

This file is the source of truth for that rollout.

## Standardization Goals

- One typography system across all screens
- One color token system (`AppColorPalette`) across all widgets
- One spacing and sizing rhythm
- Reusable common components for repeated UI patterns
- Consistent interaction behavior (tap/select/edit/random/archive/etc.)
- Consistent markdown docs format for every new screen/feature

## Scope

## In Scope

- App-wide visual consistency (Flutter UI)
- Existing and new screens
- Shared widgets in `lib/widgets/common/`
- Screen-level docs in `docs/*.md`

## Out of Scope (for now)

- Full visual redesign of all screens at once
- Rewriting business logic unrelated to presentation
- Replacing the current theme engine

## Current Baseline

- Theme + palette foundation already exists and is good.
- Inconsistent usage still exists in many screens/widgets:
  - mixed text sizes and font weights
  - lingering hardcoded colors and ad-hoc opacities
  - repeated custom controls created per screen
  - markdown docs with different structure/level of detail

## Design Tokens (Authoritative)

Use `AppColorPalette` and theme manager as authoritative token sources.

## Color Rules

- Use semantic palette tokens first:
  - `primary`, `accent`, `success`, `warning`, `error`, `info`
- Avoid raw `Colors.*` except `Colors.transparent` or unavoidable framework constraints.
- Avoid direct `Color(0xFF...)` in screens/widgets.

## Typography Rules

- Use theme-derived sizes and families:
  - body: `fontPrimary` + `fontSizeBody`
  - titles/headings: `fontSecondary` + `fontSizeHeading`/`fontSizeTitle`
- Keep heading scale consistent per hierarchy.
- Define and reuse text styles instead of ad-hoc per widget when possible.

## Spacing Rules

- Standard spacing scale: `4, 8, 12, 16, 20, 24, 32`
- Corner radii scale: `6, 10, 12, 16, 20`
- Section blocks default to `16` horizontal/vertical padding.

## Component Standardization Targets

Create/expand reusable building blocks so screens stop re-implementing visuals:

- Header cards with optional action overlay
- Counter controls (plus/minus with min/max/step)
- Day-state bars/indicators
- Tokenized chips and tags
- Standard modal/dialog shells
- Standard add/select bottom sheets

## Interaction Consistency Rules

Use these patterns app-wide:

- First tap on unselected card = select only
- Second tap on selected card = open details modal
- Random reroll excludes current item when alternatives exist
- Hide random button if no valid reroll candidates
- Archive action uses deterministic fallback selection

## Markdown Documentation Standard

Every screen/feature doc should follow a single structure:

1. **Purpose**
2. **Entry points**
3. **UI sections/components**
4. **Interaction rules**
5. **State model + persistence**
6. **Edge cases**
7. **Files touched**
8. **Test checklist**
9. **Open questions**

## Markdown Naming Convention

- Screen docs: `docs/<screen_name>_screen.md`
- Plans: `docs/<area>_plan.md`
- Cross-cutting standards: `docs/<topic>_master_plan.md`

## Markdown Quality Rules

- Keep sections short and scannable
- Prefer bullet rules over long paragraphs
- Include defaults and constraints explicitly
- Include “non-goals” to prevent scope drift
- Update docs in same PR as UI behavior changes

## Rollout Phases

## Phase 0 - Audit (1 pass)

- Build an inventory:
  - hardcoded colors
  - font/style inconsistencies
  - duplicated controls
  - undocumented UI flows
- Output: migration checklist by file/screen.

## Phase 1 - Token Enforcement

- Replace remaining hardcoded color usage in high-traffic screens.
- Normalize typography to theme-based styles.
- Add lint/check script for forbidden color patterns (`Color(0x`, direct `Colors.*` where avoidable).

## Phase 2 - Shared Components

- Extract recurring custom controls into reusable widgets.
- Replace per-screen copies with shared components.

## Phase 3 - Screen Harmonization

- Apply standardized spacing/typography/interactions to key screens:
  - Home / Pomodoro
  - Room Management
  - Projects Management
  - Workout / Analytics / Rewards

## Phase 4 - Markdown Harmonization

- Bring existing docs into standard template.
- Ensure each updated screen has:
  - interaction rules
  - persistence notes
  - checklist

## Phase 5 - Regression Review

- Visual review by screen (light/dark, all palettes)
- Accessibility checks (contrast, text sizes, tap targets)
- Interaction checks against consistency rules

## Acceptance Criteria

- No new screen introduces hardcoded color literals
- Key screens use shared component primitives for repeated patterns
- Typography hierarchy is consistent across major screens
- Interaction patterns match standard rules
- Every modified screen has an updated markdown doc in standard format

## Suggested Workboard Tasks

- [ ] Create UI audit checklist doc
- [ ] Add lint/search guard for hardcoded colors
- [ ] Extract `CounterField` and `DayStateStrip` into shared widgets
- [ ] Normalize Home screen typography and spacing
- [ ] Normalize Room Management screen typography and spacing
- [ ] Normalize Projects Management screen typography and spacing
- [ ] Migrate remaining docs to markdown template
- [ ] Perform visual regression pass (all palettes)

## Notes

- Existing palette/theme docs remain valid and should be referenced, not replaced.
- This plan is execution-oriented and should be updated as each phase is completed.
