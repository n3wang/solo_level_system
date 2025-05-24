import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class Recorder extends StatefulWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop});

  @override
  State<Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      if (path != null) widget.onStop(path);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
      }
    }
    setState(() => _isRecording = !_isRecording);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.red),
      onPressed: _toggleRecording,
    );
  }
}
