import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_asset.dart';
import 'demonstration_media.dart';

class StepDemonstrationButton extends StatefulWidget {
  final String mediaId;
  final Future<MediaAsset?> Function(String id) resolveAsset;
  final Future<Uri?> Function(String id) resolveUri;
  final Future<void> Function() onReplace;
  final Future<void> Function() onRemove;
  final double width;
  final double height;
  final double borderRadius;

  const StepDemonstrationButton({
    super.key,
    required this.mediaId,
    required this.resolveAsset,
    required this.resolveUri,
    required this.onReplace,
    required this.onRemove,
    this.width = 40,
    this.height = 40,
    this.borderRadius = 10,
  });

  @override
  State<StepDemonstrationButton> createState() =>
      _StepDemonstrationButtonState();
}

class _StepDemonstrationButtonState extends State<StepDemonstrationButton> {
  late Future<(MediaAsset?, Uri?)> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = _resolve();
  }

  @override
  void didUpdateWidget(covariant StepDemonstrationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _resolved = _resolve();
    }
  }

  Future<(MediaAsset?, Uri?)> _resolve() async => (
        await widget.resolveAsset(widget.mediaId),
        await widget.resolveUri(widget.mediaId),
      );

  Future<void> _openPreview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Demonstration',
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: DemonstrationMedia(
                    mediaId: widget.mediaId,
                    paused: false,
                    resolveAsset: () => widget.resolveAsset(widget.mediaId),
                    resolveUri: () => widget.resolveUri(widget.mediaId),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await widget.onRemove();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete demonstration'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await widget.onReplace();
                      },
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Replace demonstration'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(MediaAsset?, Uri?)>(
        future: _resolved,
        builder: (context, snapshot) {
          final asset = snapshot.data?.$1;
          final uri = snapshot.data?.$2;
          return Tooltip(
            message: 'View demonstration',
            child: InkWell(
              onTap: _openPreview,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: asset == null || uri == null
                        ? const Center(
                            child: Icon(Icons.perm_media_outlined, size: 24),
                          )
                        : asset.type == 'video'
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.movie_outlined,
                                      size: widget.width >= 60 ? 30 : 20,
                                    ),
                                  ),
                                  Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: widget.width >= 60 ? 34 : 20,
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File.fromUri(uri),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 24,
                                  ),
                                ),
                              ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
