import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/media_asset.dart';

abstract class MediaRepository {
  Future<MediaAsset?> get(String id);
  Future<MediaAsset> importFile(File file, {String type = 'video'});
  Future<MediaAsset> importBytes(List<int> bytes,
      {required String fileName, String type = 'video'});
  Future<bool> exists(String id);
  Future<Uri?> resolveUri(String id);
}

class LocalMediaRepository implements MediaRepository {
  final Directory? rootDirectory;
  Directory? _root;
  Map<String, MediaAsset>? _assets;

  LocalMediaRepository({this.rootDirectory});

  Future<void> initialize() async {
    if (_assets != null) return;
    final documents = rootDirectory ?? await getApplicationDocumentsDirectory();
    _root = rootDirectory ??
        Directory('${documents.path}${Platform.pathSeparator}media_library');
    await _root!.create(recursive: true);
    final index = File('${_root!.path}${Platform.pathSeparator}index.json');
    if (!await index.exists()) {
      _assets = {};
      return;
    }
    try {
      final values = jsonDecode(await index.readAsString()) as List;
      _assets = {
        for (final value in values)
          MediaAsset.fromJson(Map<String, dynamic>.from(value)).id:
              MediaAsset.fromJson(Map<String, dynamic>.from(value)),
      };
      await _migrateReadablePaths();
    } catch (_) {
      // A damaged index must not make workouts unusable. New imports rebuild
      // valid entries; orphan cleanup can be offered separately.
      _assets = {};
    }
  }

  @override
  Future<MediaAsset?> get(String id) async {
    await initialize();
    final normalized = id.replaceAll('\\', '/').toLowerCase();
    final byId = _assets![normalized];
    if (byId != null) return byId;
    for (final asset in _assets!.values) {
      if (asset.relativePath.replaceAll('\\', '/').toLowerCase() ==
          normalized) {
        return asset;
      }
    }
    return null;
  }

  @override
  Future<bool> exists(String id) async {
    final asset = await get(id);
    if (asset == null) return false;
    return File(_absolutePath(asset.relativePath)).exists();
  }

  @override
  Future<MediaAsset> importFile(File file, {String type = 'video'}) async =>
      importBytes(await file.readAsBytes(),
          fileName: file.uri.pathSegments.last, type: type);

  @override
  Future<MediaAsset> importBytes(List<int> bytes,
      {required String fileName, String type = 'video'}) async {
    await initialize();
    final digest = sha256.convert(bytes).toString();
    final id = 'sha256:$digest';
    final current = _assets![id];
    if (current != null &&
        await File(_absolutePath(current.relativePath)).exists()) {
      return current;
    }
    final extension = _safeExtension(fileName);
    final stem = _safeStem(fileName);
    final relativePath = 'media/$stem-${digest.substring(0, 8)}$extension';
    final folder = Directory('${_root!.path}${Platform.pathSeparator}media');
    await folder.create(recursive: true);
    final destination = File(_absolutePath(relativePath));
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
    final asset = MediaAsset(
      id: id,
      type: type,
      mimeType: _mimeType(extension, type),
      fileName: fileName,
      relativePath: relativePath,
      sizeBytes: bytes.length,
      createdAt: DateTime.now().toUtc(),
    );
    _assets![id] = asset;
    await _writeIndex();
    return asset;
  }

  @override
  Future<Uri?> resolveUri(String id) async {
    final asset = await get(id);
    if (asset == null) return null;
    final file = File(_absolutePath(asset.relativePath));
    return await file.exists() ? file.uri : null;
  }

  String _absolutePath(String relativePath) =>
      '${_root!.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';

  Future<void> _migrateReadablePaths() async {
    var changed = false;
    await Directory('${_root!.path}${Platform.pathSeparator}media')
        .create(recursive: true);
    for (final entry in _assets!.entries.toList()) {
      final asset = entry.value;
      final extension = _safeExtension(asset.relativePath);
      final digest = asset.id.startsWith('sha256:')
          ? asset.id.substring(7)
          : sha256
              .convert(
                  await File(_absolutePath(asset.relativePath)).readAsBytes())
              .toString();
      final readable =
          'media/${_safeStem(asset.fileName)}-${digest.substring(0, 8)}$extension';
      if (asset.relativePath == readable) continue;
      final source = File(_absolutePath(asset.relativePath));
      final destination = File(_absolutePath(readable));
      if (await source.exists() && !await destination.exists()) {
        await source.rename(destination.path);
      }
      if (await destination.exists()) {
        _assets![entry.key] = MediaAsset(
          id: asset.id,
          type: asset.type,
          mimeType: asset.mimeType,
          fileName: asset.fileName,
          relativePath: readable,
          sizeBytes: asset.sizeBytes,
          createdAt: asset.createdAt,
        );
        changed = true;
      }
    }
    if (changed) await _writeIndex();
  }

  Future<void> _writeIndex() async {
    final index = File('${_root!.path}${Platform.pathSeparator}index.json');
    final temporary = File('${index.path}.tmp');
    await temporary.writeAsString(
        jsonEncode(_assets!.values.map((asset) => asset.toJson()).toList()),
        flush: true);
    if (await index.exists()) await index.delete();
    await temporary.rename(index.path);
  }

  static String _safeExtension(String fileName) {
    final match = RegExp(r'\.[a-zA-Z0-9]{1,8}$').firstMatch(fileName);
    return match?.group(0)?.toLowerCase() ?? '';
  }

  static String _safeStem(String fileName) {
    final leaf = fileName.replaceAll('\\', '/').split('/').last;
    final dot = leaf.lastIndexOf('.');
    final raw = dot > 0 ? leaf.substring(0, dot) : leaf;
    final safe = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'demonstration' : safe;
  }

  static String _mimeType(String extension, String type) => switch (extension) {
        '.mp4' => 'video/mp4',
        '.mov' => 'video/quicktime',
        '.webm' => 'video/webm',
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        _ => '$type/octet-stream',
      };
}
