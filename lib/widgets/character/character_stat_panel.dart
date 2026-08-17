import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/heatmap_layout.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/character_stats_service.dart';

/// RPG-style character sheet: the six ability stats built up by acquiring
/// cards, plus the combat-facing numbers they derive (attack damage,
/// attack speed, armor, max health, crit/evasion, luck).
class CharacterStatPanel extends StatelessWidget {
  const CharacterStatPanel({super.key, required this.cards});

  final List<CardModel> cards;

  String _formatStat(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final totals = CharacterStatsService.totals(cards);
    final combat = CharacterCombatStats.from(totals);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = HeatmapLayout.forWidth(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppUiSizes.md),
            Center(
              child: Wrap(
                spacing: layout.gap,
                runSpacing: layout.gap,
                children: [
                  for (final stat in CharacterStat.values)
                    _StatChip(
                      label: stat.abbreviation,
                      value: _formatStat(totals[stat] ?? 0),
                      width: layout.cellSize,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppUiSizes.lg),
            Wrap(
              spacing: AppUiSizes.lg,
              runSpacing: AppUiSizes.sm,
              children: [
                _DerivedStat(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Attack Dmg',
                  value: _formatStat(combat.attackDamage),
                ),
                _DerivedStat(
                  icon: Icons.speed_outlined,
                  label: 'Attack Spd',
                  value: _formatStat(combat.attackSpeed),
                ),
                _DerivedStat(
                  icon: Icons.shield_outlined,
                  label: 'Armor',
                  value: _formatStat(combat.armor),
                ),
                _DerivedStat(
                  icon: Icons.favorite_outline,
                  label: 'Max HP',
                  value: _formatStat(combat.maxHealth),
                ),
                _DerivedStat(
                  icon: Icons.gps_fixed_outlined,
                  label: 'Crit',
                  value: '${combat.critChancePercent}%',
                ),
                _DerivedStat(
                  icon: Icons.directions_run_outlined,
                  label: 'Evasion',
                  value: '${combat.evasionChancePercent}%',
                ),
                _DerivedStat(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Luck',
                  value: _formatStat(combat.luck),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 1 / HeatmapLayout.statChipHeightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
            border: Border.all(color: scheme.outline),
            color: scheme.surfaceContainerLow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DerivedStat extends StatelessWidget {
  const _DerivedStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppUiSizes.sm, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppUiSizes.xs),
        Text(
          '$label $value',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
