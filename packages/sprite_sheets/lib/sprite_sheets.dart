// Flutter spritesheet library — cut-on-memory rendering + CLI splitter.
//
// Quick start:
//   1. Name your spritesheet: assets/icons_32px.png  (tile size from filename)
//   2. Optionally create assets/icons_32px.csv with name,number columns.
//   3. In main(): await SpriteSheets.init(sheets: [SheetSource.asset('assets/icons_32px.png')]);
//   4. In widgets: SpriteImage(sheet: 'icons_32px', name: 'sword', size: 48)

export 'src/sheet_source.dart';
export 'src/sprite_sheet_registry.dart';
export 'src/loaded_sheet.dart';
export 'src/sprite_entry.dart';
export 'src/missing_sprite_behavior.dart';
export 'src/naming_convention.dart';
export 'src/csv_parser.dart';
export 'src/grid_calculator.dart';
export 'src/sprite_image_widget.dart';
export 'src/sprite_image_painter.dart';
export 'src/sprite_image_provider.dart';
export 'src/debug/debug_overlay.dart';
