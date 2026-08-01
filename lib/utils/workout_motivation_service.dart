import 'dart:math';

import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_model.dart';

class WorkoutQuoteVm {
  final String itemId;
  final String quote;
  final String author;
  final String aboutAuthor;
  final int? imageIndex;

  const WorkoutQuoteVm({
    required this.itemId,
    required this.quote,
    required this.author,
    required this.aboutAuthor,
    this.imageIndex,
  });
}

class WorkoutMotivationService {
  WorkoutMotivationService._();

  static final Random _random = Random();

  static const WorkoutQuoteVm fallbackQuote = WorkoutQuoteVm(
    itemId: 'fallback_quote',
    quote:
        'You have power over your mind—not outside events. Realize this, and you will find strength.',
    author: 'Marcus Aurelius',
    aboutAuthor: '',
    imageIndex: null,
  );

  static WorkoutQuoteVm? randomAcquiredQuote({
    String? excludeQuote,
    String? excludeItemId,
  }) {
    if (!Hive.isBoxOpen('motivationItems')) return null;
    final box = Hive.box<CardModel>('motivationItems');

    final quotePool = <WorkoutQuoteVm>[];
    for (final item in box.values) {
      if (item.type != 'phy' || !item.hasAnyAcquisition) continue;
      final quotes = _quoteOptions(item);
      for (final quote in quotes) {
        quotePool.add(
          WorkoutQuoteVm(
            itemId: item.id,
            quote: quote,
            author: item.quotePerson?.trim().isNotEmpty == true
                ? item.quotePerson!.trim()
                : item.title,
            aboutAuthor: item.description,
            imageIndex: item.imageIndex,
          ),
        );
      }
    }

    if (quotePool.isEmpty) return null;

    final filtered = quotePool.where((entry) {
      final sameQuote = excludeQuote != null && entry.quote == excludeQuote;
      final sameItem = excludeItemId != null && entry.itemId == excludeItemId;
      return !(sameQuote && sameItem);
    }).toList();

    final source = filtered.isEmpty ? quotePool : filtered;
    return source[_random.nextInt(source.length)];
  }

  static List<String> _quoteOptions(CardModel item) {
    final quotes = <String>[];
    final metadataQuotes = item.metadata['quotes'];
    if (metadataQuotes is List) {
      for (final quote in metadataQuotes) {
        final text = quote?.toString().trim() ?? '';
        if (text.isNotEmpty) quotes.add(text);
      }
    }
    final quoteText = item.quoteText?.trim() ?? '';
    if (quoteText.isNotEmpty) {
      quotes.addAll(
        quoteText
            .split(';')
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty),
      );
    }
    return quotes.toSet().toList();
  }
}

