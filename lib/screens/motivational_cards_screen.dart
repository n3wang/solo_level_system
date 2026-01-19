// lib/screens/motivational_cards_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/motivational_card_model.dart';
import '../utils/motivational_card_service.dart';
import 'add_edit_motivational_card_screen.dart';
import 'motivational_card_detail_screen.dart';

class MotivationalCardsScreen extends StatefulWidget {
  const MotivationalCardsScreen({super.key});

  @override
  _MotivationalCardsScreenState createState() =>
      _MotivationalCardsScreenState();
}

class _MotivationalCardsScreenState extends State<MotivationalCardsScreen> {
  final _service = MotivationalCardService();

  void _navigateToAddCard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditMotivationalCardScreen(),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _navigateToEditCard(MotivationalCardModel card) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMotivationalCardScreen(card: card),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _navigateToCardDetail(MotivationalCardModel card) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MotivationalCardDetailScreen(card: card),
      ),
    );
  }

  void _deleteCard(MotivationalCardModel card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text(
          'Are you sure you want to delete this motivational card?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteCard(card.id);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Card deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting card: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: Hive.box<MotivationalCardModel>(
          'motivationalCards',
        ).listenable(),
        builder: (context, Box<MotivationalCardModel> box, _) {
          final cards = box.values.toList();

          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No motivational cards yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create your first card',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddCard,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Card'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return _buildCardTile(card);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "motivational_cards_add",
        onPressed: _navigateToAddCard,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardTile(MotivationalCardModel card) {
    return GestureDetector(
      onTap: () => _navigateToCardDetail(card),
      onLongPress: () => _showCardOptions(card),
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or color
            if (card.imagePath != null && File(card.imagePath!).existsSync())
              Image.file(File(card.imagePath!), fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha:0.7),
                      Theme.of(context).primaryColor,
                    ],
                  ),
                ),
              ),

            // Dark overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha:0.7)],
                ),
              ),
            ),

            // Text overlay
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Options button
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.more_vert),
                color: Colors.white,
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  padding: const EdgeInsets.all(4),
                ),
                onPressed: () => _showCardOptions(card),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardOptions(MotivationalCardModel card) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCardDetail(card);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEditCard(card);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteCard(card);
              },
            ),
          ],
        ),
      ),
    );
  }
}
