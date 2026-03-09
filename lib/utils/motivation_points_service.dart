import 'package:hive/hive.dart';
import 'package:solo_level_system/models/motivation_points_transaction_model.dart';

class MotivationPointsSummary {
  final int totalEarned;
  final int totalSpent;
  final int lastWeekEarned;
  final int lastWeekSpent;

  const MotivationPointsSummary({
    required this.totalEarned,
    required this.totalSpent,
    required this.lastWeekEarned,
    required this.lastWeekSpent,
  });
}

class MotivationPointsService {
  static const String _boxName = 'motivationPointsTransactions';

  static void recordEarned({
    required int amount,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) {
    _addTransaction(
      kind: 'earned',
      amount: amount,
      source: source,
      metadata: metadata,
    );
  }

  static void recordSpent({
    required int amount,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) {
    _addTransaction(
      kind: 'spent',
      amount: amount,
      source: source,
      metadata: metadata,
    );
  }

  static void _addTransaction({
    required String kind,
    required int amount,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) {
    if (amount <= 0 || !Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<MotivationPointsTransactionModel>(_boxName);
    box.add(
      MotivationPointsTransactionModel(
        id: '${DateTime.now().microsecondsSinceEpoch}_$kind',
        kind: kind,
        amount: amount,
        source: source,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  static MotivationPointsSummary summary() {
    if (!Hive.isBoxOpen(_boxName)) {
      return const MotivationPointsSummary(
        totalEarned: 0,
        totalSpent: 0,
        lastWeekEarned: 0,
        lastWeekSpent: 0,
      );
    }
    final box = Hive.box<MotivationPointsTransactionModel>(_boxName);
    final txs = box.values.toList();
    final weekStart = DateTime.now().subtract(const Duration(days: 7));

    int totalEarned = 0;
    int totalSpent = 0;
    int lastWeekEarned = 0;
    int lastWeekSpent = 0;

    for (final tx in txs) {
      final isEarned = tx.kind == 'earned';
      if (isEarned) {
        totalEarned += tx.amount;
      } else {
        totalSpent += tx.amount;
      }

      if (tx.createdAt.isAfter(weekStart)) {
        if (isEarned) {
          lastWeekEarned += tx.amount;
        } else {
          lastWeekSpent += tx.amount;
        }
      }
    }

    return MotivationPointsSummary(
      totalEarned: totalEarned,
      totalSpent: totalSpent,
      lastWeekEarned: lastWeekEarned,
      lastWeekSpent: lastWeekSpent,
    );
  }
}

