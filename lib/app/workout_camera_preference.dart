import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WorkoutCameraLayout {
  split,
  pictureInPicture,
  cameraPictureInPicture,
  overlay,
}

extension WorkoutCameraLayoutLabel on WorkoutCameraLayout {
  String get label => switch (this) {
        WorkoutCameraLayout.split => 'Split',
        WorkoutCameraLayout.pictureInPicture => 'Demo main / Camera PiP',
        WorkoutCameraLayout.cameraPictureInPicture => 'Camera main / Demo PiP',
        WorkoutCameraLayout.overlay => 'Overlay',
      };
}

class WorkoutCameraPreference extends ChangeNotifier {
  WorkoutCameraPreference._();

  static final WorkoutCameraPreference instance = WorkoutCameraPreference._();

  static const _autoStartKey = 'anhpt.workoutCamera.autoStart.v1';
  static const _layoutKey = 'anhpt.workoutCamera.layout.v1';

  bool _initialized = false;
  bool _autoStart = false;
  WorkoutCameraLayout _layout = WorkoutCameraLayout.split;

  bool get initialized => _initialized;
  bool get autoStart => _autoStart;
  WorkoutCameraLayout get layout => _layout;

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await SharedPreferences.getInstance();
    _autoStart = preferences.getBool(_autoStartKey) ?? false;
    final storedLayout = preferences.getString(_layoutKey);
    _layout = WorkoutCameraLayout.values.firstWhere(
      (value) => value.name == storedLayout,
      orElse: () => WorkoutCameraLayout.split,
    );
    _initialized = true;
    notifyListeners();
  }

  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoStartKey, value);
  }

  Future<void> setLayout(WorkoutCameraLayout value) async {
    _layout = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_layoutKey, value.name);
  }
}
