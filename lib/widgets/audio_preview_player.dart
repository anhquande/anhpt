import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPreviewPlayer extends StatelessWidget {
  final String title;
  final PlayerState state;
  final Duration position;
  final Duration duration;
  final Future<void> Function() onPlayPause;
  final Future<void> Function(double milliseconds) onSeek;
  final Future<void> Function() onStop;

  const AudioPreviewPlayer({
    super.key,
    required this.title,
    required this.state,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onStop,
  });

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.audio_file_outlined, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip:
                state == PlayerState.playing ? 'Pause preview' : 'Play preview',
            onPressed: onPlayPause,
            icon: Icon(state == PlayerState.playing
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill),
          ),
          const SizedBox(width: 8),
          Text('${_time(position)} / ${_time(duration)}'),
          IconButton(
            tooltip: 'Stop preview',
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ]),
        Slider(
          value: duration.inMilliseconds <= 0
              ? 0
              : position.inMilliseconds
                  .clamp(0, duration.inMilliseconds)
                  .toDouble(),
          max: duration.inMilliseconds <= 0
              ? 1
              : duration.inMilliseconds.toDouble(),
          onChanged: duration.inMilliseconds <= 0 ? null : onSeek,
        ),
      ]),
    );
  }
}
