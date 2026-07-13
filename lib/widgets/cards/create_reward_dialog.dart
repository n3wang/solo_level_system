import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solo_level_system/config/app_environment.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/collectible_card_layout.dart';
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

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
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
          );

          return AlertDialog(
            title: const Text('Create Reward'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    child: AspectRatio(
                      aspectRatio: CollectibleCardLayout.aspectRatio,
                      child: CollectibleCardTile(
                        card: previewCard,
                        overrideLocalImagePath: localImagePath,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppUiSizes.lg),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: AppUiSizes.md),
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
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppUiSizes.sm),
                      OutlinedButton(
                        onPressed: () {
                          final current =
                              int.tryParse(pointsController.text.trim()) ?? 0;
                          pointsController.text = '${current + 10}';
                          setDialogState(() {});
                        },
                        child: const Text('+10'),
                      ),
                      const SizedBox(width: AppUiSizes.xs),
                      OutlinedButton(
                        onPressed: () {
                          final current =
                              int.tryParse(pointsController.text.trim()) ?? 0;
                          final next = (current - 10).clamp(1, 1 << 30);
                          pointsController.text = '$next';
                          setDialogState(() {});
                        },
                        child: const Text('-10'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Category',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: AppUiSizes.xs),
                  Wrap(
                    spacing: AppUiSizes.xs,
                    runSpacing: AppUiSizes.xs,
                    children: [
                      for (final cat in kRewardCategories)
                        IconButton(
                          tooltip: cat,
                          isSelected: rewardCategory == cat,
                          onPressed: () {
                            setDialogState(() => rewardCategory = cat);
                          },
                          icon: Icon(collectibleCategoryIcon(cat)),
                          style: IconButton.styleFrom(
                            backgroundColor: rewardCategory == cat
                                ? Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.15)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppUiSizes.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (picked == null) return;
                      final dir = await getApplicationDocumentsDirectory();
                      final dest = File(
                        '${dir.path}/reward_${DateTime.now().millisecondsSinceEpoch}.jpg',
                      );
                      await File(picked.path).copy(dest.path);
                      setDialogState(() => localImagePath = dest.path);
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      localImagePath == null
                          ? 'Add image (optional)'
                          : 'Change image',
                    ),
                  ),
                  if (localImagePath != null)
                    TextButton(
                      onPressed: () =>
                          setDialogState(() => localImagePath = null),
                      child: const Text('Remove image'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final points = int.tryParse(pointsController.text.trim()) ?? 0;
                  if (title.isEmpty || points <= 0) return;

                  final reward = RewardTemplates.createCustomReward(
                    title: title,
                    description: description.isEmpty
                        ? 'Custom reward'
                        : description,
                    pointsCost: points,
                    category: rewardCategory,
                  );
                  if (localImagePath != null) {
                    reward.metadata = {
                      ...reward.metadata,
                      'localImagePath': localImagePath,
                    };
                  }
                  await Hive.box<RewardModel>('rewards').add(reward);

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  showAppSnack(
                    dialogContext,
                    text: 'Reward card created',
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );

  titleController.dispose();
  descriptionController.dispose();
  pointsController.dispose();
}
