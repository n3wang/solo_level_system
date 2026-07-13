// lib/screens/manage_programs_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/timed_workout_model.dart';
import 'package:solo_level_system/screens/add_edit_timed_program_screen.dart';
import 'package:solo_level_system/widgets/common/on_off_toggle.dart';

class ManageProgramsScreen extends StatelessWidget {
  const ManageProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Programs'),
      ),
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<TimedWorkoutModel>('timedWorkouts').listenable(),
        builder: (context, Box<TimedWorkoutModel> box, _) {
          final programs = box.values.toList()
            ..sort((a, b) {
              if (a.isSubscribed && !b.isSubscribed) return -1;
              if (!a.isSubscribed && b.isSubscribed) return 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          if (programs.isEmpty) {
            return const Center(child: Text('No programs yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: programs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final program = programs[index];
              return _ProgramManageTile(program: program);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manage_create_program',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditTimedProgramScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }
}

class _ProgramManageTile extends StatelessWidget {
  final TimedWorkoutModel program;

  const _ProgramManageTile({required this.program});

  @override
  Widget build(BuildContext context) {
    final accent = AppColorPalette.color2;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        onTap: program.isCustom
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditTimedProgramScreen(program: program),
                  ),
                );
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
            border: Border.all(color: AppColorPalette.grey300),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: program.isSubscribed
                      ? AppColorPalette.grey800
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppUiSizes.buttonRadius),
                  border: Border.all(
                    color: program.isSubscribed
                        ? AppColorPalette.grey800
                        : AppColorPalette.grey400,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: program.isSubscribed
                      ? AppColorPalette.white
                      : AppColorPalette.grey700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${program.formattedDuration} · ${program.workoutOrder.length} steps'
                      '${program.isCustom ? ' · custom' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              OnOffToggle(
                value: program.isSubscribed,
                activeColor: accent,
                onChanged: (value) => program.setSubscribed(value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
