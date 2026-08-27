import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class StepRecordingMiniPlayer extends StatefulWidget {
  final String audioPath;
  final VoidCallback onManage;

  const StepRecordingMiniPlayer({
    super.key,
    required this.audioPath,
    required this.onManage,
  });

  @override
  State<StepRecordingMiniPlayer> createState() =>
      _StepRecordingMiniPlayerState();
}

class _StepRecordingMiniPlayerState extends State<StepRecordingMiniPlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  StreamSubscription<PlayerState>? _stateSubscription;
  Timer? _touchHideTimer;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  void _setActionsVisible(bool visible) {
    _touchHideTimer?.cancel();
    if (mounted && _showActions != visible) {
      setState(() => _showActions = visible);
    }
  }

  void _showActionsForTouch() {
    _setActionsVisible(true);
    _touchHideTimer = Timer(const Duration(seconds: 4), () {
      _setActionsVisible(false);
    });
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(DeviceFileSource(widget.audioPath));
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _setActionsVisible(true),
        onExit: (_) => _setActionsVisible(false),
        child: Listener(
          onPointerDown: (event) {
            if (event.kind != PointerDeviceKind.mouse) _showActionsForTouch();
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _state == PlayerState.playing
                        ? 'Pause recording'
                        : 'Play recording',
                    onPressed: _toggle,
                    icon: Icon(_state == PlayerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                  ),
                  if (_showActions) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Manage recording',
                      onPressed: widget.onManage,
                      icon: const Icon(Icons.settings_voice_outlined),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _touchHideTimer?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
