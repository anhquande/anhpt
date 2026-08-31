import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/media_asset.dart';
import 'common.dart';
import 'step_demonstration_button.dart';
import 'step_recording_mini_player.dart';

typedef StepRecordingCallback = void Function(BuildContext context, WorkoutStep step, String stepKey);
typedef StepMediaCallback = void Function(BuildContext context, WorkoutStep step, String stepKey);

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onStart;
  final VoidCallback onFavorite;
  final String? sourceName;
  final String? originalName;

  const WorkoutCard({super.key, required this.workout, required this.onStart, required this.onFavorite, this.sourceName, this.originalName});

  IconData _thumbnailIcon() {
    final tags = workout.tags.map((tag) => tag.toLowerCase()).toSet();
    if (tags.any((tag) => tag.contains('karate') || tag.contains('martial'))) return Icons.sports_martial_arts;
    if (tags.any((tag) => tag.contains('yoga') || tag.contains('mobility'))) return Icons.self_improvement;
    if (tags.any((tag) => tag.contains('hiit') || tag.contains('cardio'))) return Icons.bolt;
    return Icons.fitness_center;
  }

  bool get _recommended => workout.tags.any((tag) => tag.trim().toLowerCase() == 'recommended');

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
    final time = '${used.hour.toString().padLeft(2, '0')}:${used.minute.toString().padLeft(2, '0')}';
    if (usedDate == today) return 'Last: Today, $time';
    if (usedDate == yesterday) return 'Last: Yesterday, $time';
    return 'Last: ${used.day.toString().padLeft(2, '0')}.${used.month.toString().padLeft(2, '0')}.${used.year}, $time';
  }

  Widget _recommendedBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text('✨ Recommended', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayLastUsed = workout.lastUsedAt != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onStart,
        child: SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 96,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: cs.surfaceContainerHighest, alignment: Alignment.center, child: Icon(_thumbnailIcon(), size: 32, color: cs.onSurfaceVariant)),
                if (_isNew)
                  Positioned(top: 7, left: 7, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Expanded(child: Text(workout.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (_recommended) ...[const SizedBox(width: 6), _recommendedBadge(context)],
                ]),
                const SizedBox(height: 6),
                Text('${formatDuration(workout.totalDuration)}  |  ${workout.effectiveStepCount} steps  |  ${workout.voice.language.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 3),
                SizedBox(height: 18, child: displayLastUsed ? Row(children: [Icon(Icons.history_rounded, size: 14, color: cs.primary), const SizedBox(width: 4), Expanded(child: Text(_formatLastUsed(workout.lastUsedAt!), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)))]) : (_isNew ? Text('NEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)) : null)),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(right: 6), child: IconButton(tooltip: workout.favorite ? 'Remove favorite' : 'Add to favorites', visualDensity: VisualDensity.compact, onPressed: onFavorite, icon: Icon(workout.favorite ? Icons.star_rounded : Icons.star_border_rounded, color: workout.favorite ? cs.primary : cs.onSurfaceVariant))),
          ]),
        ),
      ),
    );
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

  const WorkoutStructure({super.key, required this.nodes, this.depth = 0, this.pathPrefix = '', this.onRecordStep, this.recordedStepKeys = const {}, this.onBrowseStepMedia, this.resolveStepRecording, this.demoMediaIdForStep, this.resolveMediaAsset, this.resolveMediaUri, this.onRemoveStepMedia});

  @override
  Widget build(BuildContext context) => Column(children: List.generate(nodes.length, (index) {
    final stepKey = pathPrefix.isEmpty ? '$index' : '$pathPrefix.$index';
    return _NodeView(node: nodes[index], depth: depth, stepKey: stepKey, onRecordStep: onRecordStep, recordedStepKeys: recordedStepKeys, onBrowseStepMedia: onBrowseStepMedia, resolveStepRecording: resolveStepRecording, demoMediaIdForStep: demoMediaIdForStep, resolveMediaAsset: resolveMediaAsset, resolveMediaUri: resolveMediaUri, onRemoveStepMedia: onRemoveStepMedia);
  }));
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

  const _NodeView({required this.node, required this.depth, required this.stepKey, required this.onRecordStep, required this.recordedStepKeys, required this.onBrowseStepMedia, required this.resolveStepRecording, required this.demoMediaIdForStep, required this.resolveMediaAsset, required this.resolveMediaUri, required this.onRemoveStepMedia});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final indent = depth * 18.0;
    if (node is WorkoutStep) {
      final step = node as WorkoutStep;
      return Padding(padding: EdgeInsets.only(left: indent, bottom: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [
        Expanded(child: Text(step.name, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (onRecordStep != null && step.recording == null) IconButton(visualDensity: VisualDensity.compact, tooltip: recordedStepKeys.contains(stepKey) ? 'Edit step recording' : 'Record step cue', onPressed: () => onRecordStep!(context, step, stepKey), icon: Icon(recordedStepKeys.contains(stepKey) ? Icons.mic : Icons.mic_none_outlined, color: recordedStepKeys.contains(stepKey) ? cs.primary : cs.onSurfaceVariant)),
        if (onRecordStep != null && step.recording != null && resolveStepRecording?.call(step) != null) StepRecordingMiniPlayer(audioPath: resolveStepRecording!(step)!, onManage: () => onRecordStep?.call(context, step, stepKey)),
        if (onBrowseStepMedia != null && demoMediaIdForStep?.call(step) == null) IconButton(visualDensity: VisualDensity.compact, tooltip: step.exerciseId == null ? 'Browse demonstration files' : 'Replace demonstration media', onPressed: () => onBrowseStepMedia!(context, step, stepKey), icon: Icon(step.exerciseId == null ? Icons.add_photo_alternate_outlined : Icons.perm_media_outlined, color: step.exerciseId == null ? cs.onSurfaceVariant : cs.primary)),
        if (onBrowseStepMedia != null && onRemoveStepMedia != null && resolveMediaAsset != null && resolveMediaUri != null && demoMediaIdForStep?.call(step) != null) StepDemonstrationButton(mediaId: demoMediaIdForStep!(step)!, resolveAsset: resolveMediaAsset!, resolveUri: resolveMediaUri!, onReplace: () async => onBrowseStepMedia!(context, step, stepKey), onRemove: () async => onRemoveStepMedia!(context, step, stepKey)),
        if (onBrowseStepMedia != null) const SizedBox(width: 8),
        Text(formatDuration(step.duration)),
      ])])));
    }
    if (node is RepeatGroup) {
      final group = node as RepeatGroup;
      return Padding(padding: EdgeInsets.only(left: indent, bottom: 10), child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.primary.withValues(alpha: .35), width: 3))), padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(Icons.repeat, color: cs.primary, size: 20), const SizedBox(width: 8), Text('Repeat ×${group.repeat}', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary))]),
        const SizedBox(height: 8),
        WorkoutStructure(nodes: group.steps, depth: depth + 1, pathPrefix: stepKey, onRecordStep: onRecordStep, recordedStepKeys: recordedStepKeys, onBrowseStepMedia: onBrowseStepMedia, resolveStepRecording: resolveStepRecording, demoMediaIdForStep: demoMediaIdForStep, resolveMediaAsset: resolveMediaAsset, resolveMediaUri: resolveMediaUri, onRemoveStepMedia: onRemoveStepMedia),
      ])));
    }
    return const SizedBox.shrink();
  }
}
