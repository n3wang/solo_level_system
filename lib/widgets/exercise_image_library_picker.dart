// lib/widgets/exercise_image_library_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/widgets/workout_icon_widget.dart';

/// Picker grid of built-in exercise icons (from workout_icons CSV).
class ExerciseImageLibraryPicker extends StatefulWidget {
  const ExerciseImageLibraryPicker({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: const ExerciseImageLibraryPicker(),
      ),
    );
  }

  @override
  State<ExerciseImageLibraryPicker> createState() =>
      _ExerciseImageLibraryPickerState();
}

class _ExerciseImageLibraryPickerState extends State<ExerciseImageLibraryPicker> {
  List<String> _slugs = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadSlugs();
  }

  Future<void> _loadSlugs() async {
    try {
      final csv = await rootBundle.loadString(
        'assets/icon/workout_icons_128px.csv',
      );
      final lines = csv.split('\n').skip(1); // header
      final slugs = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final name = trimmed.split(',').first.trim();
        if (name.isNotEmpty) slugs.add(name);
      }
      if (mounted) {
        setState(() {
          _slugs = slugs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _slugs
        : _slugs
            .where((s) => s.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Exercise images',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search icons…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No icons found',
                        style: TextStyle(color: AppColorPalette.textSecondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final slug = filtered[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, slug),
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: WorkoutIconWidget(
                                    imageUrl: slug,
                                    size: 72,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slug.replaceAll('_', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
