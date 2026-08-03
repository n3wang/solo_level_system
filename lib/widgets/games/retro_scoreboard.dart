import 'package:flutter/material.dart';
import 'package:solo_level_system/constants/app_ui_sizes.dart';
import 'package:solo_level_system/constants/color_palette.dart';

/// One row on a retro rank / score / date board.
class RetroScoreEntry {
  const RetroScoreEntry({
    required this.score,
    required this.at,
  });

  final int score;
  final DateTime at;
}

/// Arcade-style high-score table reusable across mini-games summaries.
class RetroScoreboard extends StatelessWidget {
  const RetroScoreboard({
    super.key,
    required this.entries,
    this.highlightIndex,
    this.emptyLabel = 'No scores yet',
    this.maxRows = 10,
  });

  final List<RetroScoreEntry> entries;
  final int? highlightIndex;
  final String emptyLabel;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final rows = entries.take(maxRows).toList();
    final primary = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 0.8),
        borderRadius: BorderRadius.circular(AppUiSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _Header('RANK', flex: 2),
              _Header('SCORE', flex: 3, align: TextAlign.right),
              _Header('DATE', flex: 4, align: TextAlign.right),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1.2, color: Colors.black54),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyLabel,
                style: TextStyle(color: AppColorPalette.textSecondary),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _ScoreRow(
                rank: i + 1,
                entry: rows[i],
                highlight: highlightIndex == i,
                isNewHighScore: highlightIndex == i && i == 0,
                accent: primary,
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label, {required this.flex, this.align = TextAlign.left});

  final String label;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.entry,
    required this.highlight,
    required this.isNewHighScore,
    required this.accent,
  });

  final int rank;
  final RetroScoreEntry entry;
  final bool highlight;
  final bool isNewHighScore;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColorPalette.textColor,
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
      fontSize: 13,
    );
    final dateLabel = isNewHighScore
        ? 'High Score! · ${_formatShortDate(entry.at)}'
        : _formatShortDate(entry.at);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? accent.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_ordinal(rank), style: style)),
          Expanded(
            flex: 3,
            child: Text(
              '${entry.score}',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              dateLabel,
              textAlign: TextAlign.right,
              style: style.copyWith(
                color: highlight ? accent : AppColorPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

String _formatShortDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
