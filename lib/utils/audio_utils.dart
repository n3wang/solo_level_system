import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Maps [record] package microphone readings ([Amplitude.current], roughly −160…0 dB)
/// into 0…1 for UI (levels, waveform peaks).
double normalizeMicDb(double db, {double silenceDb = -48, double loudDb = -10}) {
  return ((db - silenceDb) / (loudDb - silenceDb)).clamp(0.0, 1.0);
}

Future<String?> recordAudio(BuildContext context) async {
  // Placeholder: Implement real recording logic with permission handling.
  final dir = await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
  );
  await file.writeAsBytes([]); // Dummy file
  return file.path;
}
