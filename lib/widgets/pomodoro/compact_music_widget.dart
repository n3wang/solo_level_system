import 'package:flutter/material.dart';

class CompactMusicWidget extends StatelessWidget {
  final bool allowMusic;
  final String? currentlyPlayingTrack;

  const CompactMusicWidget({
    Key? key,
    required this.allowMusic,
    this.currentlyPlayingTrack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allowMusic
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allowMusic ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                allowMusic ? Icons.music_note : Icons.music_off,
                size: 16,
                color: allowMusic ? Colors.green : Colors.grey,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  allowMusic
                      ? currentlyPlayingTrack ?? 'Unknown Track'
                      : 'Music Muted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: allowMusic ? Colors.green : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Tap Timer Area • ← → Swipe for Random Track',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}