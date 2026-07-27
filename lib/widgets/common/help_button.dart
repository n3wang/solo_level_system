import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/utils/unlock_service.dart';

/// A `?` control that appears on a screen only when an `option` card (guide
/// variant) mapped to [screenKey] has been unlocked in the Motivation hub.
/// Tapping it opens a how-to modal sourced from the unlocked option card.
///
/// Renders nothing (a zero-size box) when no guide option is unlocked, so it
/// is safe to drop into any AppBar `actions:` list unconditionally.
class HelpButton extends StatelessWidget {
  final String screenKey;

  const HelpButton({super.key, required this.screenKey});

  @override
  Widget build(BuildContext context) {
    final listenable = UnlockService.changes();
    if (listenable == null) return _button(context);
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) => _button(context),
    );
  }

  Widget _button(BuildContext context) {
    final guide = UnlockService.guideFor(screenKey);
    if (guide == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'How to use',
      icon: const Icon(Icons.help_outline),
      onPressed: () => _showGuide(context, guide),
    );
  }

  Future<void> _showGuide(BuildContext context, GuideContent guide) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(guide.body, style: Theme.of(context).textTheme.bodyMedium),
              if (guide.tips.isNotEmpty) ...[
                const SizedBox(height: AppUiSizes.md),
                Text(
                  'Tips',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppUiSizes.xs),
                for (final tip in guide.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppUiSizes.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            tip,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
