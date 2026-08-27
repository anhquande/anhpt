import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/background_music.dart';
import 'package:anhpt/services/background_music_service.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/music_library_service.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/screens/music_library_screen.dart';
import 'package:anhpt/widgets/audio_preview_player.dart';
import 'package:anhpt/widgets/workout_music_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('browsed music keeps a readable file name with numeric collisions',
      () async {
    final directory = await Directory.systemTemp.createTemp('anhpt-music-');
    addTearDown(() => directory.delete(recursive: true));
    final sourceOne = File('${directory.path}/source-one.mp3');
    final sourceTwo = File('${directory.path}/source-two.mp3');
    await sourceOne.writeAsBytes([1]);
    await sourceTwo.writeAsBytes([2]);
    final service = MusicLibraryService(documentsDirectory: directory);

    final first = await service.copyToLibrary(sourceOne, 'Morning Flow.mp3');
    final second = await service.copyToLibrary(sourceTwo, 'Morning Flow.mp3');

    expect(
        first.path.replaceAll('\\', '/'), endsWith('/music/Morning Flow.mp3'));
    expect(second.path.replaceAll('\\', '/'),
        endsWith('/music/Morning Flow-2.mp3'));
  });

  test('MP3 ID3 title wins over generated storage filename', () {
    final title = utf8.encode('Morning Flow');
    final payload = <int>[3, ...title];
    final frameSize = payload.length;
    final frame = <int>[
      ...ascii.encode('TIT2'),
      0,
      0,
      0,
      frameSize,
      0,
      0,
      ...payload,
    ];
    final tagSize = frame.length;
    final bytes = Uint8List.fromList([
      ...ascii.encode('ID3'),
      3,
      0,
      0,
      (tagSize >> 21) & 0x7f,
      (tagSize >> 14) & 0x7f,
      (tagSize >> 7) & 0x7f,
      tagSize & 0x7f,
      ...frame,
    ]);

    expect(MusicLibraryService.titleFromId3Bytes(bytes), 'Morning Flow');
  });

  test('music filename fallback is clean and hides generated ids', () {
    expect(MusicLibraryService.cleanFileName(r'C:\Music\Morning_Flow.mp3'),
        'Morning Flow');
    expect(MusicLibraryService.cleanFileName('track_123456789.mp3'),
        'Imported track');
    expect(
        MusicLibraryService.cleanFileName('Track + ID.mp3'), 'Imported track');
  });

  test('supported format helper uses the picker extension source of truth', () {
    expect(MusicLibraryService.supportedExtensions,
        ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'wma']);
    expect(MusicLibraryService.supportedFormatsLabel,
        'Supported: MP3, WAV, M4A, AAC, FLAC, OGG, WMA');
  });

  testWidgets('music library import exposes supported formats tooltip',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    await tester.pumpWidget(MaterialApp(
      home: MusicLibraryScreen(controller: controller),
    ));
    await tester.pump();

    expect(find.byTooltip(MusicLibraryService.supportedFormatsLabel),
        findsOneWidget);
  });

  test('music metadata and assignment round trip', () {
    final track = MusicTrack(
        id: 't1',
        name: 'Flow',
        mood: 'Calm',
        source: 'x.mp3',
        bundled: false,
        createdAt: DateTime.utc(2026));
    final restored = MusicTrack.fromJson(track.toJson());
    final config = WorkoutMusicConfig(
        workoutId: 'w1',
        trackId: track.id,
        enabled: true,
        baseVolume: .4,
        duckingMode: 'gentle');
    expect(restored.name, 'Flow');
    expect(WorkoutMusicConfig.fromJson(config.toJson()).baseVolume, .4);
  });

  test('deleting personal track clears every affected workout assignment',
      () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    controller.musicTracks = [
      MusicTrack(
          id: 't1',
          name: 'Flow',
          mood: 'Calm',
          source: 'missing.mp3',
          bundled: false,
          createdAt: DateTime.utc(2026))
    ];
    controller.workoutMusic = {
      'w1': const WorkoutMusicConfig(
          workoutId: 'w1', trackId: 't1', enabled: true),
      'w2': const WorkoutMusicConfig(
          workoutId: 'w2', trackId: 't1', enabled: true)
    };
    await controller.deleteMusicTrack('t1');
    expect(controller.musicConfigFor('w1').trackId, isNull);
    expect(controller.musicConfigFor('w2').enabled, isFalse);
  });

  test('ducking factors preserve gentle intent', () {
    expect(BackgroundMusicService.duckFactor('off'), 1);
    expect(BackgroundMusicService.duckFactor('gentle'), closeTo(.82, .001));
    expect(BackgroundMusicService.duckFactor('medium'), .6);
    expect(BackgroundMusicService.duckFactor('high'), .4);
    expect(BackgroundMusicService.duckFactor('very_high'), .2);
  });

  test('shared ducking controller follows live volume and mode changes',
      () async {
    final volumes = <double>[];
    final controller = AudioDuckingController(
      setVolume: (volume) async => volumes.add(volume),
      baseVolume: .5,
      duckingMode: 'gentle',
    );

    controller.setCoachActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(volumes.last, closeTo(.41, .001));

    controller.update(baseVolume: .8, duckingMode: 'medium');
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(volumes.last, closeTo(.48, .001));

    controller.setCoachActive(false);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(volumes.last, closeTo(.8, .001));
    controller.cancel();
  });

  testWidgets('music preview shares player layout and wide ducking row',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    final track = MusicTrack(
      id: 'bundled-soft-bell',
      name: 'Soft Bell Pulse',
      mood: 'Calm',
      source: 'audio/bell.wav',
      bundled: true,
      createdAt: DateTime.utc(2026),
    );
    controller.musicTracks = [track];
    final workout = WorkoutParser.parse('''
version: 2
name: Music layout
background_music:
  source: "asset:audio/bell.wav"
  name: Soft Bell Pulse
steps:
  - name: Plank
''', id: 'workout-1', defaultVoiceLanguage: 'en');
    controller.workouts = [workout];

    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            child: WorkoutMusicCard(controller: controller, workout: workout),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(AudioPreviewPlayer), findsOneWidget);
    expect(find.byTooltip('Play preview'), findsOneWidget);
    expect(find.byTooltip('Stop preview'), findsOneWidget);
    final playerBottom =
        tester.getBottomLeft(find.byType(AudioPreviewPlayer)).dy;
    final volumeTop =
        tester.getTopLeft(find.text('Background music volume 35%')).dy;
    expect(playerBottom, lessThan(volumeTop));
    final duckingCenter = tester.getCenter(find.text('Coach ducking'));
    final testCenter =
        tester.getCenter(find.text('Test ducking with coach voice'));
    expect((duckingCenter.dy - testCenter.dy).abs(), lessThan(40));
  });
}
