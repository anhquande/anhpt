import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class MusicLibraryService {
  Future<String?> importAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'flac',
        'ogg',
        'opus',
        'wma',
      ],
      allowMultiple: false,
      lockParentWindow: true,
      dialogTitle: 'Import offline background music',
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return null;
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}music');
    await directory.create(recursive: true);
    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.audio';
    final target =
        '${directory.path}${Platform.pathSeparator}track_${DateTime.now().microsecondsSinceEpoch}$extension';
    await File(sourcePath).copy(target);
    return target;
  }

  Future<bool> exists(String path) => File(path).exists();
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
