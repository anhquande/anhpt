import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/background_music.dart';
import 'package:anhpt/services/background_music_service.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
  });
}
