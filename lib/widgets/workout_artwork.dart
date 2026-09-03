import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/workout_bucket.dart';
import '../services/workout_bucket_service.dart';

enum WorkoutArtworkKind { thumbnail, feature }

class WorkoutArtwork extends StatelessWidget {
  final List<String> tags;
  final WorkoutArtworkKind kind;
  final WorkoutBucketEntry? bucketEntry;
  final WorkoutBucketService? bucketService;
  final BoxFit fit;

  const WorkoutArtwork({
    super.key,
    required this.tags,
    required this.kind,
    this.bucketEntry,
    this.bucketService,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      defaultWorkoutArtwork(tags, kind),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
    final entry = bucketEntry;
    final service = bucketService;
    if (entry == null || service == null) return fallback;
    final hasRemoteArtwork = kind == WorkoutArtworkKind.thumbnail
        ? entry.thumbnailUrl != null
        : entry.featureImageUrl != null;
    if (!hasRemoteArtwork) return fallback;

    final download = kind == WorkoutArtworkKind.thumbnail
        ? service.downloadThumbnail(entry)
        : service.downloadFeatureImage(entry);
    return FutureBuilder<Uint8List?>(
      future: download,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return fallback;
        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}

String defaultWorkoutArtwork(List<String> tags, WorkoutArtworkKind kind) {
  final firstTag = tags.isEmpty ? '' : tags.first.trim().toLowerCase();
  final category = switch (firstTag) {
    'yoga' || 'yogo' || 'mobility' => 'yoga',
    'hiit' || 'cardio' => 'hiit',
    'meditation' ||
    'mediation' ||
    'thiền' ||
    'thien' ||
    'breathing' => 'meditation',
    'tabata' || 'interval' => 'tabata',
    'karate' || 'martial' || 'martial-arts' || 'kata' => 'martial-arts',
    _ => 'strength',
  };
  final folder = kind == WorkoutArtworkKind.thumbnail ? 'thumbnail' : 'feature';
  return 'assets/workout_artwork/$folder/$category.webp';
}
