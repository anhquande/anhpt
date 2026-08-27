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
  final Directory? documentsDirectory;

  MusicLibraryService({this.documentsDirectory});

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
    final originalFileName = sourcePath.split(RegExp(r'[\\/]')).last;
    final target = await copyToLibrary(File(sourcePath), originalFileName);
    return ImportedMusicFile(
      path: target.path,
      originalFileName: originalFileName,
    );
  }

  Future<Directory> _musicDirectory() async {
    final root = documentsDirectory ?? await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}music');
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> copyToLibrary(File source, String preferredFileName) async {
    final destination = await _availableDestination(
      preferredFileName,
      fallbackExtension: _extension(source.path),
    );
    return source.copy(destination.path);
  }

  Future<String> moveToLibrary(String sourcePath, String preferredName) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    final destination = await _availableDestination(
      preferredName,
      fallbackExtension: _extension(source.path),
      currentPath: source.path,
    );
    if (destination.path.toLowerCase() == source.path.toLowerCase()) {
      return source.path;
    }
    return (await source.rename(destination.path)).path;
  }

  Future<File> _availableDestination(
    String preferredName, {
    required String fallbackExtension,
    String? currentPath,
  }) async {
    final directory = await _musicDirectory();
    final safe =
        readableFileName(preferredName, fallbackExtension: fallbackExtension);
    final dot = safe.lastIndexOf('.');
    final stem = dot > 0 ? safe.substring(0, dot) : safe;
    final extension = dot > 0 ? safe.substring(dot) : fallbackExtension;
    var fileName = '$stem$extension';
    var suffix = 2;
    while (true) {
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      if (currentPath != null &&
          file.path.toLowerCase() == currentPath.toLowerCase()) {
        return file;
      }
      if (!await file.exists()) return file;
      fileName = '$stem-${suffix++}$extension';
    }
  }

  static String readableFileName(String value,
      {String fallbackExtension = '.audio'}) {
    var leaf = value.split(RegExp(r'[\\/]')).last.trim();
    leaf = leaf.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-');
    leaf = leaf.replaceAll(RegExp(r'\s+'), ' ').trim();
    leaf = leaf.replaceAll(RegExp(r'[. ]+$'), '');
    if (leaf.isEmpty) leaf = 'music$fallbackExtension';
    if (!RegExp(r'\.[a-zA-Z0-9]{1,8}$').hasMatch(leaf)) {
      leaf = '$leaf$fallbackExtension';
    }
    return leaf;
  }

  static String _extension(String path) {
    final leaf = path.split(RegExp(r'[\\/]')).last;
    final dot = leaf.lastIndexOf('.');
    return dot > 0 ? leaf.substring(dot).toLowerCase() : '.audio';
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
