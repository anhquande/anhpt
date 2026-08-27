import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DemonstrationVideo extends StatefulWidget {
  final Future<Uri?> Function() resolveUri;
  final String mediaId;
  final bool paused;

  const DemonstrationVideo({
    super.key,
    required this.resolveUri,
    required this.mediaId,
    required this.paused,
  });

  @override
  State<DemonstrationVideo> createState() => _DemonstrationVideoState();
}

class _DemonstrationVideoState extends State<DemonstrationVideo> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DemonstrationVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _load();
    } else if (oldWidget.paused != widget.paused) {
      widget.paused ? _controller?.pause() : _controller?.play();
    }
  }

  Future<void> _load() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (mounted) setState(() => _error = null);
    try {
      final uri = await widget.resolveUri();
      if (uri == null) {
        throw StateError('Video is not available on this device.');
      }
      final controller = VideoPlayerController.file(File.fromUri(uri));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!widget.paused) await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'Demonstration video unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(height: 80, child: Center(child: Text(_error!)));
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator()));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
