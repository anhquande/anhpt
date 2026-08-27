import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImportedMusicFile {
  final String path;
  final String originalFileName;

  const ImportedMusicFile({required this.path, required this.originalFileName});
}

class MusicLibraryService {
  static const supportedExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'wma',
  ];

  static String get supportedFormatsLabel =>
      'Supported: ${supportedExtensions.map((value) => value.toUpperCase()).join(', ')}';

  Future<ImportedMusicFile?> importAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
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
    return ImportedMusicFile(
      path: target,
      originalFileName: sourcePath.split(RegExp(r'[\\/]')).last,
    );
  }

  Future<String> resolveDisplayName(
    String path, {
    String? originalFileName,
    String? persistedName,
  }) async {
    if (path.toLowerCase().endsWith('.mp3')) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final length = await file.length();
          final reader = await file.open();
          try {
            final head =
                await reader.read(length.clamp(0, 1024 * 1024).toInt());
            final title = titleFromId3Bytes(Uint8List.fromList(head));
            if (title != null) return title;
            if (length >= 128) {
              await reader.setPosition(length - 128);
              final tail = await reader.read(128);
              final id3v1 = titleFromId3v1Bytes(Uint8List.fromList(tail));
              if (id3v1 != null) return id3v1;
            }
          } finally {
            await reader.close();
          }
        }
      } catch (_) {
        // Metadata is optional; filename fallback remains usable.
      }
    }
    final preferred = originalFileName ?? persistedName ?? path;
    return cleanFileName(preferred);
  }

  static String cleanFileName(String value) {
    var name = value.split(RegExp(r'[\\/]')).last;
    name = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'[_]+'), ' ').trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty ||
        RegExp(r'^track\s*(?:\+\s*id|id|\d+)$', caseSensitive: false)
            .hasMatch(name) ||
        RegExp(r'^personal\s*\d+$', caseSensitive: false).hasMatch(name)) {
      return 'Imported track';
    }
    return name;
  }

  static String? titleFromId3Bytes(Uint8List bytes) {
    if (bytes.length < 10 ||
        bytes[0] != 0x49 ||
        bytes[1] != 0x44 ||
        bytes[2] != 0x33) {
      return null;
    }
    final version = bytes[3];
    if (version != 3 && version != 4) return null;
    final tagSize = _synchsafe(bytes, 6);
    final limit = (10 + tagSize).clamp(10, bytes.length);
    var offset = 10;
    while (offset + 10 <= limit) {
      final id =
          ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
      if (id.codeUnits.every((value) => value == 0)) break;
      final size = version == 4
          ? _synchsafe(bytes, offset + 4)
          : _bigEndian32(bytes, offset + 4);
      offset += 10;
      if (size <= 0 || offset + size > limit) break;
      if (id == 'TIT2') {
        return _decodeTextFrame(bytes.sublist(offset, offset + size));
      }
      offset += size;
    }
    return null;
  }

  static String? titleFromId3v1Bytes(Uint8List bytes) {
    if (bytes.length != 128 || ascii.decode(bytes.sublist(0, 3)) != 'TAG') {
      return null;
    }
    return _cleanTitle(latin1.decode(bytes.sublist(3, 33)));
  }

  static int _synchsafe(Uint8List bytes, int offset) =>
      (bytes[offset] & 0x7f) << 21 |
      (bytes[offset + 1] & 0x7f) << 14 |
      (bytes[offset + 2] & 0x7f) << 7 |
      (bytes[offset + 3] & 0x7f);

  static int _bigEndian32(Uint8List bytes, int offset) =>
      bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];

  static String? _decodeTextFrame(Uint8List frame) {
    if (frame.length < 2) return null;
    final encoding = frame[0];
    final data = frame.sublist(1);
    String value;
    if (encoding == 0) {
      value = latin1.decode(data);
    } else if (encoding == 3) {
      value = utf8.decode(data, allowMalformed: true);
    } else {
      var littleEndian = false;
      var start = 0;
      if (encoding == 1 && data.length >= 2) {
        littleEndian = data[0] == 0xff && data[1] == 0xfe;
        if ((data[0] == 0xff && data[1] == 0xfe) ||
            (data[0] == 0xfe && data[1] == 0xff)) {
          start = 2;
        }
      }
      final units = <int>[];
      for (var index = start; index + 1 < data.length; index += 2) {
        units.add(littleEndian
            ? data[index] | data[index + 1] << 8
            : data[index] << 8 | data[index + 1]);
      }
      value = String.fromCharCodes(units);
    }
    return _cleanTitle(value);
  }

  static String? _cleanTitle(String value) {
    final title = value.replaceAll('\u0000', '').trim();
    return title.isEmpty ? null : title;
  }

  Future<bool> exists(String path) => File(path).exists();
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
