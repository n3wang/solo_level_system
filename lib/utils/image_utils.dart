import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<String?> capturePhoto(BuildContext context) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.camera);
  if (pickedFile == null) return null;

  final dir = await getApplicationDocumentsDirectory();
  final newPath =
      '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final newFile = await File(pickedFile.path).copy(newPath);
  return newFile.path;
}
