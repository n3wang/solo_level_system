import 'dart:io';

import 'src/info_command.dart';
import 'src/pack_command.dart';
import 'src/split_command.dart';
import 'src/validate_command.dart';

/// CLI entry point.
///
/// Usage:
///   dart run sprite_sheets:spritesheet <command> [args]
///   dart pub global activate sprite_sheets && spritesheet <command> [args]
///
/// Commands:
///   split     Slice a spritesheet into individual named files
///   pack      Pack individual files into a spritesheet + CSV
///   validate  Check sheet + CSV consistency
///   info      Quick sheet inspection
void main(List<String> args) {
  if (args.isEmpty) {
    _printHelp();
    exit(0);
  }

  final command = args.first;
  final rest = args.skip(1).toList();

  switch (command) {
    case 'split':
      runSplit(rest);
    case 'pack':
      runPack(rest);
    case 'validate':
      runValidate(rest);
    case 'info':
      runInfo(rest);
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
    default:
      stderr.writeln('Unknown command: "$command"');
      _printHelp();
      exit(1);
  }
}

void _printHelp() {
  stdout.writeln('''
spritesheet — Flutter spritesheet CLI

Commands:
  split      <image> [--tile WxH] [--csv path] [--output dir] [--prefix p]
             Slice a spritesheet into individual named files.

  pack       <directory> --size WxH [--output stem]
             Pack individual image files into a spritesheet + CSV.

  validate   <image> [--tile WxH] [--csv path]
             Check that a sheet and its CSV are consistent.

  info       <image> [--tile WxH]
             Print tile dimensions, grid size, and slot count.

Run "spritesheet <command> --help" for per-command options.
''');
}
