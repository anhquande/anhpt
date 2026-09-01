import 'package:yaml/yaml.dart';

class WorkoutVideoSettings {
  static const defaultLayout = 'picture_in_picture';
  static const defaultCamera = 'front';

  final bool autoEnable;
  final String layout;
  final String camera;

  const WorkoutVideoSettings({
    this.autoEnable = false,
    this.layout = defaultLayout,
    this.camera = defaultCamera,
  });

  static WorkoutVideoSettings? fromYaml(String yamlText) {
    try {
      final root = loadYaml(yamlText);
      if (root is! YamlMap) return null;
      final rawVideo = root['video'];
      if (rawVideo == null || rawVideo is! YamlMap) return null;
      return WorkoutVideoSettings(
        autoEnable: rawVideo['auto_enable'] is bool
            ? rawVideo['auto_enable'] as bool
            : false,
        layout: rawVideo['layout']?.toString() ?? defaultLayout,
        camera: rawVideo['camera']?.toString() ?? defaultCamera,
      );
    } catch (_) {
      return null;
    }
  }
}

class WorkoutVideoRuntime {
  static WorkoutVideoSettings? current;
}
