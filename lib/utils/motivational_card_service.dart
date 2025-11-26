// lib/utils/motivational_card_service.dart
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/motivational_card_model.dart';

class MotivationalCardService {
  static const String _boxName = 'motivationalCards';

  // Get all motivational cards
  List<MotivationalCardModel> getAllCards() {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    return box.values.toList();
  }

  // Get a single card by ID
  MotivationalCardModel? getCard(String id) {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    return box.values.firstWhere(
      (card) => card.id == id,
      orElse: () => throw Exception('Card not found'),
    );
  }

  // Create a new motivational card
  Future<MotivationalCardModel> createCard({
    required String text,
    String? imagePath,
  }) async {
    final box = Hive.box<MotivationalCardModel>(_boxName);

    final card = MotivationalCardModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );

    await box.add(card);
    return card;
  }

  // Update an existing card
  Future<void> updateCard({
    required String id,
    String? text,
    String? imagePath,
  }) async {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    final cardIndex = box.values.toList().indexWhere((card) => card.id == id);

    if (cardIndex == -1) {
      throw Exception('Card not found');
    }

    final existingCard = box.getAt(cardIndex);
    if (existingCard == null) return;

    final updatedCard = MotivationalCardModel(
      id: existingCard.id,
      text: text ?? existingCard.text,
      imagePath: imagePath ?? existingCard.imagePath,
      createdAt: existingCard.createdAt,
      updatedAt: DateTime.now(),
    );

    await box.putAt(cardIndex, updatedCard);
  }

  // Delete a card
  Future<void> deleteCard(String id) async {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    final cardIndex = box.values.toList().indexWhere((card) => card.id == id);

    if (cardIndex != -1) {
      final card = box.getAt(cardIndex);
      // Delete image file if it exists
      if (card?.imagePath != null) {
        try {
          final file = File(card!.imagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting image file: $e');
        }
      }
      await box.deleteAt(cardIndex);
    }
  }

  // Pick an image from gallery
  Future<String?> pickImageFromGallery() async {
    // Request storage/photo permission
    PermissionStatus status;
    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      // For other platforms, proceed without permission check
      status = PermissionStatus.granted;
    }

    if (!status.isGranted) {
      throw Exception('Storage permission denied');
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return null;

    return await _saveImage(pickedFile.path);
  }

  // Pick an image from camera
  Future<String?> pickImageFromCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      throw Exception('Camera permission denied');
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return null;

    return await _saveImage(pickedFile.path);
  }

  // Get Android SDK version
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    // This is a simplified version - in production you might want to use
    // a package like device_info_plus to get the actual Android version
    return 33; // Assume Android 13+ for now
  }

  // Save image to app directory
  Future<String> _saveImage(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'motivational_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = '${dir.path}/$fileName';
    final newFile = await File(sourcePath).copy(newPath);
    return newFile.path;
  }

  // Get count of cards
  int getCardCount() {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    return box.length;
  }
}
