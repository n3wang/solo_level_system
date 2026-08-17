import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
import 'package:solo_level_system/constants/color_palette.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/models/reward_model.dart';
import 'package:solo_level_system/utils/card_repository.dart';
import 'package:solo_level_system/widgets/cards/collectible_card.dart';
import 'package:solo_level_system/widgets/common/app_snack.dart';

/// Shared Create Reward dialog (Cards hub + Stats Overview FAB).
Future<void> showCreateRewardDialog(BuildContext context) async {
  if (!Hive.isBoxOpen('rewards')) {
    await Hive.openBox<RewardModel>('rewards');
  }

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final pointsController = TextEditingController(
    text: AppEnvironment.quickCreateDefaultCost.toString(),
  );
  var rewardCategory = 'general';
  String? localImagePath;
  var isBookmarked = true;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery);
            if (picked == null) return;
            final dir = await getApplicationDocumentsDirectory();
            final dest = File(
              '${dir.path}/reward_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await File(picked.path).copy(dest.path);
            setDialogState(() => localImagePath = dest.path);
          }

          void adjustPoints(int delta) {
            final current =
                int.tryParse(pointsController.text.trim()) ??
                AppEnvironment.quickCreateDefaultCost;
            final next = (current + delta).clamp(1, 1 << 30);
            pointsController.text = '$next';
            setDialogState(() {});
          }

          Future<void> saveReward() async {
            final title = titleController.text.trim();
            final description = descriptionController.text.trim();
            final points = int.tryParse(pointsController.text.trim()) ?? 0;
            if (title.isEmpty || points <= 0) return;

            final reward = RewardTemplates.createCustomReward(
              title: title,
              description: description.isEmpty ? 'Custom reward' : description,
              pointsCost: points,
              category: rewardCategory,
            );
            final meta = <String, dynamic>{...reward.metadata};
            if (localImagePath != null) {
              meta['localImagePath'] = localImagePath;
            }
            if (isBookmarked) {
              meta['isBookmarked'] = true;
            }
            reward.metadata = meta;
            await Hive.box<RewardModel>('rewards').add(reward);

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            showAppSnack(dialogContext, text: 'Reward card created');
          }

          final previewCard = CatalogCard(
            id: 'preview',
            type: CardType.reward,
            title: titleController.text.trim().isEmpty
                ? 'Reward'
                : titleController.text.trim(),
            description: descriptionController.text.trim(),
            category: rewardCategory,
            pointsCost:
                int.tryParse(pointsController.text.trim()) ??
                AppEnvironment.quickCreateDefaultCost,
            isAcquired: false,
            localImagePath: localImagePath,
            isBookmarked: isBookmarked,
          );

          final theme = Theme.of(context);
          final screenHeight = MediaQuery.sizeOf(context).height;

          return AlertDialog(
            contentPadding: const EdgeInsets.all(AppUiSizes.lg),
            content: SizedBox(
              width: CollectibleCardLayout.detailModalWidth,
              height:
                  screenHeight * CollectibleCardLayout.detailModalHeightFactor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Reward',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        onPressed: () {
                          setDialogState(() => isBookmarked = !isBookmarked);
                        },
                      ),
                      TextButton(
                        onPressed: saveReward,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 118,
                        child: AspectRatio(
                          aspectRatio: CollectibleCardLayout.aspectRatio,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: pickImage,
                              onLongPress: localImagePath == null
                                  ? null
                                  : () => setDialogState(
                                      () => localImagePath = null,
                                    ),
                              borderRadius: BorderRadius.circular(
                                AppUiSizes.radiusMd,
                              ),
                              child: CollectibleCardTile(
                                card: previewCard,
                                overrideLocalImagePath: localImagePath,
                                forceRevealContents: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppUiSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                isDense: true,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: AppUiSizes.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: pointsController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Points cost',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppUiSizes.sm),
                                _WorkoutStepButton(
                                  text: '−10',
                                  tooltip: 'Decrease by 10',
                                  onPressed: () => adjustPoints(-10),
                                ),
                                const SizedBox(width: AppUiSizes.xs),
                                _WorkoutStepButton(
                                  text: '+10',
                                  tooltip: 'Increase by 10',
                                  onPressed: () => adjustPoints(10),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppUiSizes.sm),
                            Text(
                              'Category',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(height: AppUiSizes.xs),
                            Wrap(
                              spacing: AppUiSizes.xs,
                              runSpacing: AppUiSizes.xs,
                              children: [
                                for (final cat in kRewardCategories)
                                  IconButton(
                                    tooltip: cat,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    isSelected: rewardCategory == cat,
                                    onPressed: () {
                                      setDialogState(
                                        () => rewardCategory = cat,
                                      );
                                    },
                                    icon: Icon(
                                      collectibleCategoryIcon(cat),
                                      size: 20,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: rewardCategory == cat
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.15)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Text('Description', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppUiSizes.xs),
                  Expanded(
                    child: TextField(
                      controller: descriptionController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Optional description',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  descriptionController.dispose();
  pointsController.dispose();
}

/// Matches workout session shortcut stepper button styling.
class _WorkoutStepButton extends StatelessWidget {
  final String text;
  final String tooltip;
  final VoidCallback onPressed;

  const _WorkoutStepButton({
    required this.text,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColorPalette.color3;
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: accent,
          foregroundColor: AppColorPalette.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUiSizes.buttonRadius),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
