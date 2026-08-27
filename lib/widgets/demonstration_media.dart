import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_asset.dart';
import 'demonstration_video.dart';

class DemonstrationMedia extends StatefulWidget {
  final String mediaId;
  final bool paused;
  final Future<MediaAsset?> Function() resolveAsset;
  final Future<Uri?> Function() resolveUri;

  const DemonstrationMedia({
    super.key,
    required this.mediaId,
    required this.paused,
    required this.resolveAsset,
    required this.resolveUri,
  });

  @override
  State<DemonstrationMedia> createState() => _DemonstrationMediaState();
}

class _DemonstrationMediaState extends State<DemonstrationMedia> {
  late Future<(MediaAsset?, Uri?)> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = _resolve();
  }

  @override
  void didUpdateWidget(covariant DemonstrationMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) _resolved = _resolve();
  }

  Future<(MediaAsset?, Uri?)> _resolve() async =>
      (await widget.resolveAsset(), await widget.resolveUri());

  @override
  Widget build(BuildContext context) => FutureBuilder<(MediaAsset?, Uri?)>(
        future: _resolved,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final asset = snapshot.data?.$1;
          final uri = snapshot.data?.$2;
          if (asset == null || uri == null) {
            return const SizedBox(
              height: 80,
              child: Center(child: Text('Demonstration media unavailable')),
            );
          }
          if (asset.type == 'video') {
            return DemonstrationVideo(
              mediaId: widget.mediaId,
              paused: widget.paused,
              resolveUri: widget.resolveUri,
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File.fromUri(uri),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('Demonstration media unavailable'),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
