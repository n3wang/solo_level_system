# Flutter Spritesheet Configuration Library — Design Document (v2)

## Core Principles

1. **Cut-on-memory at runtime** — the full spritesheet stays as one GPU texture; individual sprites are painted via `drawImageRect`. No pre-cutting, no memory duplication.
2. **CLI as a standalone splitter** — a platform-agnostic CLI tool that physically splits spritesheets into named individual files. Works for any project (Unity, Godot, web, React Native) — not just Dart.
3. **Naming convention as default, config as override** — file names encode tile size by convention; explicit configuration available when convention doesn't fit.
4. **Auto-calculate everything possible** — cut count, grid dimensions, and validation are derived from image dimensions and tile size. The developer declares intent; the library handles the math.
5. **Fail gracefully with context** — adopt multi-level fallback chains, contextual `[Module]` logging, fuzzy-match suggestions, and safe defaults (patterns proven in this project's `configLoader`, `inventoryLoader`, and `iconLoader`).

---

## Standardized Naming Convention

The filename is the source of truth for tile dimensions:

```
{name}_{width}px.{ext}         → square tiles (width x width)
{name}_{width}x{height}px.{ext} → non-square tiles (width x height)
```

### Examples

| Filename | Tile Width | Tile Height | Shape |
|----------|-----------|-------------|-------|
| `icons_32px.png` | 32 | 32 | Square |
| `items_64px.png` | 64 | 64 | Square |
| `characters_32x48px.png` | 32 | 48 | Portrait |
| `banners_128x32px.png` | 128 | 32 | Landscape |
| `ui_elements_24px.webp` | 24 | 24 | Square |

### Parsing Rules

```
Regex: /^(.+?)_(\d+)(?:x(\d+))?px$/

Match group 1 → sheet name
Match group 2 → tile width
Match group 3 → tile height (if absent, height = width)
```

Applied to the **filename stem** only (extension stripped first). The underscore before the size token is mandatory — it disambiguates `items_64px` (name="items", size=64) from `items64px` (ambiguous: is the name "items6" at 4px?).

### Convention Override

When the naming convention doesn't fit (legacy files, third-party sheets), configure explicitly:

```dart
await SpriteSheets.init(
  sheets: [
    // Convention-based (auto-parsed from filename)
    SheetSource.asset('assets/icons_32px.png'),

    // Explicit override — ignores filename parsing
    SheetSource.asset(
      'assets/legacy_character_sheet.png',
      tileWidth: 32,
      tileHeight: 48,
      csv: 'assets/legacy_character_sheet.csv',
    ),
  ],
);
```

---

## Auto-Calculated Grid & Cut Count

The library derives everything from two inputs: **image dimensions** and **tile size**.

```
Given: image = 320x160, tile = 32x32

columns    = floor(320 / 32) = 10
rows       = floor(160 / 32) = 5
totalCuts  = columns * rows   = 50
remainder_x = 320 % 32        = 0  ✓
remainder_y = 160 % 32        = 0  ✓
```

### Edge Case Handling (Adopted from Project Patterns)

Following the fallback-and-warn strategy used in `configLoader.ts` and `inventoryLoader.ts`:

#### 1. Remainder Pixels (image doesn't divide evenly)

```
Image: 300x160, tile: 32x32
columns = floor(300 / 32) = 9  (usable: 288px)
remainder_x = 300 % 32 = 12px

[SpriteSheet] WARNING: 'icons_32px.png' width (300) is not a multiple of 32.
  → 12px remainder on the right edge will be ignored.
  → Usable area: 288x160 (9 columns x 5 rows = 45 cuts).
  → If this is unintentional, resize to 320x160 for a clean 10x5 grid.
```

**Behavior:** Ignore remainder pixels, proceed with the valid grid. Warn but don't crash. This matches the project's pattern of logging `[InventoryLoader] WARNING: ...` and continuing with available data.

#### 2. CSV has more entries than grid slots

```
Grid has 50 slots, CSV lists 55 entries.

[SpriteSheet] WARNING: 'icons_32px.csv' has 55 entries but the grid only has 50 slots.
  → Entries beyond index 49 will be ignored: 'rare_gem', 'dark_orb', ...
  → Either expand the spritesheet or remove excess CSV rows.
```

**Behavior:** Load the first 50, warn about the rest. Same pattern as `inventoryLoader` silently handling missing items but logging context.

#### 3. CSV has fewer entries than grid slots

```
Grid has 50 slots, CSV lists 30 entries.

[SpriteSheet] INFO: 'icons_32px.csv' maps 30 of 50 available grid slots.
  → 20 slots are unnamed (indices 30-49).
```

**Behavior:** This is normal — sparse sheets are expected. Info-level log only.

#### 4. Explicit `number` in CSV points outside the grid

```
CSV row: "dragon,72" but grid only has 50 slots.

[SpriteSheet] WARNING: Sprite 'dragon' references index 72, but grid has 50 slots (0-49).
  → Skipping 'dragon'. Check the CSV or expand the spritesheet.
```

**Behavior:** Skip the invalid entry, warn with actionable context.

#### 5. Image too small for even one tile

```
Image: 20x20, tile: 32x32

[SpriteSheet] ERROR: 'icons_32px.png' is 20x20 but tile size is 32x32.
  → Image must be at least 32x32 to contain one tile.
  → This sheet will not be loaded.
```

**Behavior:** Skip the entire sheet. This is the only case that produces an error rather than a warning.

#### 6. Missing CSV companion

```
[SpriteSheet] INFO: No CSV found for 'icons_32px.png'.
  → Sprites will be accessible by index only (0 to 49).
  → To add names, create 'assets/icons_32px.csv' with a 'name' column.
```

**Behavior:** Fall back to index-only access. Same pattern as `iconLoader.ts` falling back from named icons → category placeholders → `misc_generic`.

---

## Runtime Architecture: Cut-on-Memory

```
┌────────────────────────────────────────────┐
│            GPU Texture Memory              │
│  ┌──────────────────────────────────────┐  │
│  │      Full Spritesheet (1 texture)    │  │
│  │  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐    │  │
│  │  │00│01│02│03│04│05│06│07│08│09│    │  │
│  │  ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤    │  │
│  │  │10│11│12│13│14│15│16│17│18│19│    │  │
│  │  ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤    │  │
│  │  │20│21│22│23│24│25│26│27│28│29│    │  │
│  │  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘    │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  Request: sprite('sword') → index 5        │
│  Lookup:  col=5, row=0 → Rect(160,0,32,32) │
│  Paint:   canvas.drawImageRect(src, dst)    │
│           ↑ single GPU blit, no allocation  │
└────────────────────────────────────────────┘
```

### Why Cut-on-Memory

- **Zero allocation per sprite** — `drawImageRect` selects a source rectangle from the existing texture. No new `ui.Image` objects created.
- **One texture bind** — multiple sprites from the same sheet in one frame share the same GPU texture. Critical for sprite-heavy UIs (inventories, icon grids).
- **Memory efficiency** — a 512x512 spritesheet = ~1MB RGBA. Pre-cutting into 256 individual 32x32 images = ~256KB pixel data + 256x object overhead + 256x texture binds = worse.

### Cache Strategy

```dart
class SpriteSheetCache {
  // Sheet name → loaded sheet (image + manifest)
  final Map<String, LoadedSheet> _sheets = {};

  // Lazy load: decode image only on first access
  // Keep decoded: sheet stays in memory until explicitly released
  // LRU eviction: optional, for apps with many sheets
}
```

Follows the project's `cachedConfig` pattern in `configLoader.ts` — load once, cache, expose `clearCache()` for invalidation.

---

## CLI Tool: Standalone Splitter

The CLI is a **separate, platform-agnostic tool** — not tied to Flutter runtime. It physically splits spritesheets into individual image files named by the CSV. Useful for:

- Non-Dart projects (Unity, Godot, React Native, web)
- Asset pipelines and CI/CD
- Designers previewing what each sprite looks like
- Generating individual files from a packed sheet for platforms that don't support runtime cutting

### Commands

#### `split` — Spritesheet → Individual Files

```bash
# Convention-based (reads tile size from filename)
spritesheet split icons_32px.png --csv icons_32px.csv --output ./out/

# Output:
#   out/sword.png        (32x32)
#   out/shield.png       (32x32)
#   out/potion.png       (32x32)
#   out/helmet.png       (32x32)

# Explicit tile size (override naming convention)
spritesheet split legacy_sheet.png --tile 64x32 --csv manifest.csv --output ./out/

# No CSV — use index as name
spritesheet split icons_32px.png --output ./out/
#   out/0.png
#   out/1.png
#   out/2.png
#   ...

# With prefix and format
spritesheet split icons_32px.png --csv icons_32px.csv --output ./out/ \
  --prefix "icon_" \
  --format webp \
  --quality 90
#   out/icon_sword.webp
#   out/icon_shield.webp
```

#### `pack` — Individual Files → Spritesheet (reverse operation)

```bash
spritesheet pack ./icons/ --size 32 --output icons_32px
#   icons_32px.png   (packed spritesheet)
#   icons_32px.csv   (generated manifest from filenames)

# Non-square tiles
spritesheet pack ./characters/ --size 32x48 --output characters_32x48px
```

#### `validate` — Check sheet + CSV consistency

```bash
spritesheet validate icons_32px.png --csv icons_32px.csv

# Output:
# ✓ Image: 320x320 (10 cols x 10 rows = 100 slots)
# ✓ Tile: 32x32 (from filename convention)
# ✓ CSV: 85 entries, all indices valid (0-99)
# ✓ No duplicate names
# ⚠ 15 grid slots have no CSV name (indices: 85-99)
```

#### `info` — Quick inspection

```bash
spritesheet info icons_32px.png

# Output:
# File:    icons_32px.png
# Size:    320x320
# Tile:    32x32 (from filename)
# Grid:    10 x 10
# Slots:   100
# CSV:     icons_32px.csv (found)
# Entries: 85 named sprites
```

### CLI Output Naming Rules

When splitting, the output filename comes from the CSV `name` column:

| CSV Name | Output File | Notes |
|----------|-------------|-------|
| `sword` | `sword.png` | Direct mapping |
| `Fire Ball` | `fire_ball.png` | Spaces → underscores, lowercased |
| `shield+1` | `shield_1.png` | Special chars → underscores |
| *(no CSV)* | `0.png`, `1.png` | Index-based fallback |
| *(duplicate name)* | `sword.png`, `sword_1.png` | Auto-suffix on collision |

Sanitization regex: replace `[^a-zA-Z0-9_-]` with `_`, collapse multiple `_`, trim leading/trailing `_`.

### CLI as Standalone Binary

The CLI should be distributable without requiring Dart/Flutter:

```bash
# Install options:
# 1. Dart/Flutter users
dart pub global activate sprite_sheets

# 2. Standalone binary (compiled with dart compile exe)
# Download from GitHub releases — works on macOS, Linux, Windows
# No Dart SDK needed

# 3. npx wrapper (for JS/TS ecosystem interop)
npx spritesheet-cli split icons_32px.png --csv icons_32px.csv
```

---

## Dart API

### Initialization

```dart
await SpriteSheets.init(
  sheets: [
    // Auto-discover: scans directory, pairs .png/.csv by naming convention
    ...SheetSource.discover('assets/sprites/'),

    // Explicit single sheet
    SheetSource.asset('assets/icons_32px.png'),

    // Full override
    SheetSource.asset(
      'assets/old_sprites.png',
      tileWidth: 48,
      tileHeight: 48,
      csv: 'assets/old_sprites_manifest.csv',
    ),
  ],
  // Optional: custom fallback when a sprite name isn't found
  onMissing: MissingSpriteBehavior.placeholder, // or .error, .transparent
);
```

### Usage

```dart
// Widget — most common
SpriteImage(sheet: 'icons_32px', name: 'sword')
SpriteImage(sheet: 'icons_32px', index: 5)  // by index when no CSV

// ImageProvider — for BoxDecoration, CircleAvatar, etc.
final provider = SpriteSheets.of('icons_32px').provider('sword');
Image(image: provider)

// Raw rect — for custom painters, game loops
final entry = SpriteSheets.of('icons_32px').entry('sword');
// entry.sourceRect → Rect(160, 0, 32, 32)
// entry.sheet.image → ui.Image (the full sheet)

// Query by metadata
final weapons = SpriteSheets.of('items_64px')
    .where((e) => e.tags.contains('weapon'));

// Sheet info
final info = SpriteSheets.of('icons_32px').info;
// info.columns → 10
// info.rows → 10
// info.totalSlots → 100
// info.namedCount → 85
// info.tileWidth → 32
// info.tileHeight → 32
```

### Missing Sprite Handling (Fallback Chain)

Borrowed from the project's `iconLoader.ts` pattern:

```
1. Exact name match in the sheet's CSV
2. Fuzzy match suggestion (Levenshtein ≤ 2) → warn + return closest
3. onMissing behavior:
   a. MissingSpriteBehavior.placeholder → render a magenta "?" tile (debug-visible)
   b. MissingSpriteBehavior.transparent → render an empty rect (silent)
   c. MissingSpriteBehavior.error → throw with suggestions

[SpriteSheet] WARNING: Sprite 'swrod' not found in 'icons_32px'.
  → Did you mean: 'sword'? (distance: 1)
  → Using placeholder. Set onMissing to .error for strict mode.
```

---

## CSV Format (Unchanged, Formalized)

### Minimal (index = row order)
```csv
name
sword
shield
potion
```

### Explicit Index
```csv
name,number
sword,0
shield,5
potion,12
```

### Extended Metadata
```csv
name,number,tags,category
sword,0,weapon;melee,equipment
shield,5,armor;defense,equipment
potion,12,consumable;healing,items
```

Rules:
- First row is always the header
- `name` column is required (or the file has no header and every row is a name in order)
- `number` column is optional; if absent, row order = index
- Extra columns are passed through as `Map<String, String>` metadata
- UTF-8 encoding; BOM is stripped if present
- Empty rows and rows starting with `#` are skipped

---

## File Structure (Library Package)

```
sprite_sheets/
├── lib/
│   ├── sprite_sheets.dart              # Public API barrel
│   ├── src/
│   │   ├── sheet_source.dart           # SheetSource config class
│   │   ├── sprite_sheet_registry.dart   # SpriteSheets singleton + cache
│   │   ├── loaded_sheet.dart           # Loaded image + parsed manifest
│   │   ├── sprite_entry.dart           # Single sprite: name, index, rect, metadata
│   │   ├── naming_convention.dart      # Filename parser (regex)
│   │   ├── csv_parser.dart             # CSV manifest parser
│   │   ├── grid_calculator.dart        # Dimensions → grid math + validation
│   │   ├── sprite_image_widget.dart    # SpriteImage StatelessWidget
│   │   ├── sprite_image_painter.dart   # CustomPainter (drawImageRect)
│   │   └── sprite_image_provider.dart  # ImageProvider adapter
│   └── src/debug/
│       └── debug_overlay.dart          # Grid overlay for development
├── bin/
│   └── spritesheet.dart                # CLI entry point
│       ├── split_command.dart
│       ├── pack_command.dart
│       ├── validate_command.dart
│       └── info_command.dart
├── test/
│   ├── naming_convention_test.dart
│   ├── csv_parser_test.dart
│   ├── grid_calculator_test.dart
│   └── integration/
│       └── split_and_load_test.dart
└── pubspec.yaml
```

---

## Tradeoffs Summary

### Cut-on-Memory (runtime) + CLI Split (offline)

| Concern | Runtime (Cut-on-Memory) | CLI (Physical Split) |
|---------|------------------------|---------------------|
| **Memory** | 1 texture, minimal overhead | N files, N textures |
| **Performance** | Single GPU blit per sprite | Standard image load |
| **Use case** | Flutter/Dart apps | Any platform, any language |
| **Workflow** | Dev changes CSV → hot reload | Dev runs CLI → commits output |
| **Reversibility** | Non-destructive (source unchanged) | Destructive (creates files) |

They complement each other: runtime cutting is optimal for Dart apps; the CLI serves everyone else and doubles as a validation/preview tool.

### Naming Convention vs Config File

| Approach | Simplicity | Flexibility |
|----------|-----------|-------------|
| `icons_32px.png` convention only | One file = full config | Square tiles only, rigid naming |
| `icons_32x48px.png` extended convention | Still one file | Handles non-square, still requires naming discipline |
| `spritesheets.yaml` config only | Separate config step | Total flexibility, more boilerplate |
| **Convention + override (recommended)** | Zero config for 80% | Override for the 20% |

### Auto-Calculated Count vs Declared Count

| Auto-calculated | Declared in config |
|----------------|-------------------|
| Always accurate to the actual image | Can drift from the image |
| No extra config | Explicit developer intent |
| Detects cropping/resizing automatically | Fails silently if image changes |

**Auto-calculate wins.** If the image is 320x320 and the tile is 32x32, the grid is 10x10 = 100 slots. Period. The library computes this, validates it, and warns about remainders. No reason to ask the developer to also declare "100 tiles" and risk it going stale.

---

## MVP Scope (Revised)

### v0.1 — Core
- Naming convention parser (`_32px`, `_32x48px`)
- CSV parser with edge case handling
- Grid calculator with auto-count and remainder warnings
- `SpriteImage` widget (cut-on-memory via `CustomPainter`)
- Sheet cache (load once, paint many)
- Contextual error messages with fuzzy-match suggestions
- CLI `split` command (spritesheet → named files)
- CLI `info` command (quick sheet inspection)

### v0.2 — Polish
- CLI `pack` command (individual files → spritesheet + CSV)
- CLI `validate` command
- `ImageProvider` adapter
- Metadata/tag queries from CSV columns
- `SheetSource.discover()` auto-scan
- Debug overlay widget

### v0.3 — Advanced
- Optional `build_runner` code generation
- Hot reload in debug mode
- Resolution variant handling (`2.0x/`, `3.0x/`)
- Compiled standalone CLI binaries (no Dart SDK required)
- npx wrapper for JS ecosystem
