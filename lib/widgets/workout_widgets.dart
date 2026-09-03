import 'package:flutter/material.dart';

import '../models/media_asset.dart';
import '../models/workout.dart';
import '../models/workout_bucket.dart';
import '../services/workout_bucket_service.dart';
import 'common.dart';
import 'step_demonstration_button.dart';
import 'step_recording_mini_player.dart';
import 'workout_artwork.dart';

typedef StepRecordingCallback =
    void Function(BuildContext context, WorkoutStep step, String stepKey);
typedef StepMediaCallback =
    void Function(BuildContext context, WorkoutStep step, String stepKey);

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onStart;
  final VoidCallback onFavorite;
  final String? sourceName;
  final String? originalName;
  final String? availableUpdateVersion;
  final WorkoutBucketEntry? bucketEntry;
  final WorkoutBucketService? bucketService;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onStart,
    required this.onFavorite,
    this.sourceName,
    this.originalName,
    this.availableUpdateVersion,
    this.bucketEntry,
    this.bucketService,
  });

  bool get _recommended =>
      workout.tags.any((tag) => tag.trim().toLowerCase() == 'recommended');

  bool get _isNew {
    if (workout.lastUsedAt != null) return false;
    return DateTime.now().difference(workout.createdAt).inDays <= 14;
  }

  String _formatLastUsed(DateTime value) {
    final used = value.toLocal();
    final now = DateTime.now();
    final usedDate = DateUtils.dateOnly(used);
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final time =
        '${used.hour.toString().padLeft(2, '0')}:${used.minute.toString().padLeft(2, '0')}';
    if (usedDate == today) return 'Last: Today, $time';
    if (usedDate == yesterday) return 'Last: Yesterday, $time';
    return 'Last: ${used.day.toString().padLeft(2, '0')}.${used.month.toString().padLeft(2, '0')}.${used.year}, $time';
  }

  Widget _recommendedBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '✨ Recommended',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (workout.lastUsedAt != null) {
      return Row(
        children: [
          Icon(Icons.history_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _formatLastUsed(workout.lastUsedAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    if (_isNew) {
      return Text(
        'NEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _sourceIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUpdate = availableUpdateVersion != null;
    return Tooltip(
      message: hasUpdate
          ? 'Update available from $sourceName'
          : 'Downloaded from $sourceName',
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.cloud_done_outlined, color: cs.onSurfaceVariant),
            if (hasUpdate)
              Positioned(
                top: 3,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onStart,
        child: SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    WorkoutArtwork(
                      tags: workout.tags,
                      kind: WorkoutArtworkKind.thumbnail,
                      bucketEntry: bucketEntry,
                      bucketService: bucketService,
                    ),
                    if (_isNew)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workout.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_recommended) ...[
                          const SizedBox(width: 6),
                          _recommendedBadge(context),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatDuration(workout.totalDuration)}  |  ${workout.effectiveStepCount} steps  |  ${workout.voice.language.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(height: 18, child: _statusLine(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sourceName != null) _sourceIcon(context),
                    IconButton(
                      tooltip: workout.favorite
                          ? 'Remove favorite'
                          : 'Add to favorites',
                      visualDensity: VisualDensity.compact,
                      onPressed: onFavorite,
                      icon: Icon(
                        workout.favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: workout.favorite
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogWorkoutCard extends StatelessWidget {
  final WorkoutBucketEntry entry;
  final String sourceName;
  final VoidCallback onTap;
  final WorkoutBucketService bucketService;

  const CatalogWorkoutCard({
    super.key,
    required this.entry,
    required this.sourceName,
    required this.onTap,
    required this.bucketService,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 108,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: WorkoutArtwork(
                  tags: entry.tags,
                  kind: WorkoutArtworkKind.thumbnail,
                  bucketEntry: entry,
                  bucketService: bucketService,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _tagSummary(entry.tags),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Tooltip(
                  message: 'From $sourceName',
                  child: Icon(
                    Icons.cloud_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _tagSummary(List<String> tags) {
    final visible = tags.take(3).toList();
    final remaining = tags.length - visible.length;
    return [...visible, if (remaining > 0) '+$remaining'].join(' · ');
  }
}

class WorkoutStructure extends StatelessWidget {
  final List<WorkoutNode> nodes;
  final int depth;
  final String pathPrefix;
  final StepRecordingCallback? onRecordStep;
  final Set<String> recordedStepKeys;
  final StepMediaCallback? onBrowseStepMedia;
  final String? Function(WorkoutStep step)? resolveStepRecording;
  final Future<MediaAsset?> Function(String id)? resolveMediaAsset;
  final Future<Uri?> Function(String id)? resolveMediaUri;
  final StepMediaCallback? onRemoveStepMedia;
  final String? Function(WorkoutStep step)? demoMediaIdForStep;

  const WorkoutStructure({
    super.key,
    required this.nodes,
    this.depth = 0,
    this.pathPrefix = '',
    this.onRecordStep,
    this.recordedStepKeys = const {},
    this.onBrowseStepMedia,
    this.resolveStepRecording,
    this.demoMediaIdForStep,
    this.resolveMediaAsset,
    this.resolveMediaUri,
    this.onRemoveStepMedia,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(nodes.length, (index) {
      final stepKey = pathPrefix.isEmpty ? '$index' : '$pathPrefix.$index';
      return _NodeView(
        node: nodes[index],
        depth: depth,
        stepKey: stepKey,
        onRecordStep: onRecordStep,
        recordedStepKeys: recordedStepKeys,
        onBrowseStepMedia: onBrowseStepMedia,
        resolveStepRecording: resolveStepRecording,
        demoMediaIdForStep: demoMediaIdForStep,
        resolveMediaAsset: resolveMediaAsset,
        resolveMediaUri: resolveMediaUri,
        onRemoveStepMedia: onRemoveStepMedia,
      );
    }),
  );
}

class _NodeView extends StatelessWidget {
  final WorkoutNode node;
  final int depth;
  final String stepKey;
  final StepRecordingCallback? onRecordStep;
  final Set<String> recordedStepKeys;
  final StepMediaCallback? onBrowseStepMedia;
  final String? Function(WorkoutStep step)? resolveStepRecording;
  final String? Function(WorkoutStep step)? demoMediaIdForStep;
  final Future<MediaAsset?> Function(String id)? resolveMediaAsset;
  final Future<Uri?> Function(String id)? resolveMediaUri;
  final StepMediaCallback? onRemoveStepMedia;

  const _NodeView({
    required this.node,
    required this.depth,
    required this.stepKey,
    required this.onRecordStep,
    required this.recordedStepKeys,
    required this.onBrowseStepMedia,
    required this.resolveStepRecording,
    required this.demoMediaIdForStep,
    required this.resolveMediaAsset,
    required this.resolveMediaUri,
    required this.onRemoveStepMedia,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final indent = depth * 18.0;
    if (node is WorkoutStep) {
      final step = node as WorkoutStep;
      final mediaId = demoMediaIdForStep?.call(step);
      final guide = step.guide?.trim() ?? '';
      return Padding(
        padding: EdgeInsets.only(left: indent, bottom: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 76,
                  child:
                      mediaId != null &&
                          onBrowseStepMedia != null &&
                          onRemoveStepMedia != null &&
                          resolveMediaAsset != null &&
                          resolveMediaUri != null
                      ? StepDemonstrationButton(
                          mediaId: mediaId,
                          resolveAsset: resolveMediaAsset!,
                          resolveUri: resolveMediaUri!,
                          width: 76,
                          height: 76,
                          borderRadius: 0,
                          onReplace: () async =>
                              onBrowseStepMedia!(context, step, stepKey),
                          onRemove: () async =>
                              onRemoveStepMedia!(context, step, stepKey),
                        )
                      : Material(
                          color: cs.surfaceContainerHighest,
                          child: InkWell(
                            onTap: onBrowseStepMedia == null
                                ? null
                                : () => onBrowseStepMedia!(
                                    context,
                                    step,
                                    stepKey,
                                  ),
                            child: Center(
                              child: Icon(
                                onBrowseStepMedia == null
                                    ? Icons.directions_run_outlined
                                    : Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          step.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (step.duration > Duration.zero) ...[
                          const SizedBox(height: 3),
                          Text(
                            formatDuration(step.duration),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        if (guide.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            guide,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (onRecordStep != null && step.recording == null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: recordedStepKeys.contains(stepKey)
                        ? 'Edit step recording'
                        : 'Record step cue',
                    onPressed: () => onRecordStep!(context, step, stepKey),
                    icon: Icon(
                      recordedStepKeys.contains(stepKey)
                          ? Icons.mic
                          : Icons.mic_none_outlined,
                      color: recordedStepKeys.contains(stepKey)
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                  )
                else if (onRecordStep != null &&
                    step.recording != null &&
                    resolveStepRecording?.call(step) != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: StepRecordingMiniPlayer(
                        audioPath: resolveStepRecording!(step)!,
                        onManage: () =>
                            onRecordStep?.call(context, step, stepKey),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      );
    }
    if (node is RepeatGroup) {
      final group = node as RepeatGroup;
      return Padding(
        padding: EdgeInsets.only(left: indent, bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: cs.primary.withValues(alpha: .35),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.repeat, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Repeat ×${group.repeat}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              WorkoutStructure(
                nodes: group.steps,
                depth: depth + 1,
                pathPrefix: stepKey,
                onRecordStep: onRecordStep,
                recordedStepKeys: recordedStepKeys,
                onBrowseStepMedia: onBrowseStepMedia,
                resolveStepRecording: resolveStepRecording,
                demoMediaIdForStep: demoMediaIdForStep,
                resolveMediaAsset: resolveMediaAsset,
                resolveMediaUri: resolveMediaUri,
                onRemoveStepMedia: onRemoveStepMedia,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
