import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioPlayer extends StatefulWidget {
  final String source;
  final VoidCallback onDelete;

  const AudioPlayer({super.key, required this.source, required this.onDelete});

  @override
  State<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  final _audioPlayer = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);
  StreamSubscription<void>? _playerStateChangedSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateChangedSubscription = _audioPlayer.onPlayerComplete.listen(
      (_) => setState(() {}),
    );
    _audioPlayer.setSource(
      kIsWeb ? ap.UrlSource(widget.source) : ap.DeviceFileSource(widget.source),
    );
  }

  @override
  void dispose() {
    _playerStateChangedSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _audioPlayer.state == ap.PlayerState.playing
                ? Icons.pause
                : Icons.play_arrow,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () async {
            if (_audioPlayer.state == ap.PlayerState.playing) {
              await _audioPlayer.pause();
            } else {
              await _audioPlayer.play(
                kIsWeb
                    ? ap.UrlSource(widget.source)
                    : ap.DeviceFileSource(widget.source),
              );
            }
            setState(() {});
          },
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.grey),
          onPressed: () async {
            if (_audioPlayer.state == ap.PlayerState.playing) {
              await _audioPlayer.stop();
            }
            widget.onDelete();
          },
        ),
      ],
    );
  }
}
