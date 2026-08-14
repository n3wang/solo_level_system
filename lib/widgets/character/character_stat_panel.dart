import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/models/card_model.dart';
import 'package:solo_level_system/utils/character_stats_service.dart';

/// RPG-style character sheet: the six ability stats built up by acquiring
/// cards, plus the combat-facing numbers they derive (attack damage,
/// attack speed, armor, max health, crit/evasion, luck).
class CharacterStatPanel extends StatelessWidget {
  const CharacterStatPanel({super.key, required this.cards});

  final List<CardModel> cards;

  String _formatStat(double value) =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = CharacterStatsService.totals(cards);
    final combat = CharacterCombatStats.from(totals);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppUiSizes.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Character',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppUiSizes.md),
          Wrap(
            spacing: AppUiSizes.sm,
            runSpacing: AppUiSizes.sm,
            children: [
              for (final stat in CharacterStat.values)
                _StatChip(
                  label: stat.abbreviation,
                  value: _formatStat(totals[stat] ?? 0),
                ),
            ],
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
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUiSizes.md,
        vertical: AppUiSizes.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ],
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
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
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
