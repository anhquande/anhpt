import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  installing,
  error,
}

class ReleaseAsset {
  final String name;
  final Uri downloadUrl;
  final String? sha256;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.sha256,
  });
}

class AppRelease {
  final String version;
  final ReleaseAsset asset;

  const AppRelease({required this.version, required this.asset});
}

class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _repo = 'anhquande/anhpt';
  static const _autoUpdateKey = 'auto_update_enabled';
  static const _lastCheckKey = 'auto_update_last_check';

  bool autoUpdateEnabled = false;
  String currentVersion = '';
  String? latestVersion;
  DateTime? lastChecked;
  UpdateStatus status = UpdateStatus.idle;
  double downloadProgress = 0;
  String? errorMessage;
  AppRelease? _pendingRelease;
  bool _initialized = false;
  bool _cancelRequested = false;
  http.Client? _downloadClient;

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);
  bool get updateAvailable => _pendingRelease != null;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    autoUpdateEnabled = prefs.getBool(_autoUpdateKey) ?? false;
    final millis = prefs.getInt(_lastCheckKey);
    lastChecked = millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    notifyListeners();
  }

  Future<void> setAutoUpdateEnabled(bool value) async {
    autoUpdateEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, value);
    notifyListeners();
  }

  void cancelCurrentUpdate() {
    _cancelRequested = true;
    _downloadClient?.close();
    _downloadClient = null;
    downloadProgress = 0;
    status = UpdateStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> checkOnStartup() async {
    await initialize();
    if (!supported || !autoUpdateEnabled) return;
    await checkForUpdates(autoInstall: true);
  }

  Future<bool> checkForUpdates({bool autoInstall = false}) async {
    await initialize();
    if (!supported) return false;
    _cancelRequested = false;
    status = UpdateStatus.checking;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (_cancelRequested) return false;
      if (response.statusCode != 200) {
        throw HttpException('GitHub returned HTTP ${response.statusCode}.');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final release = releaseFromGitHub(json);
      latestVersion = release?.version ?? _cleanVersion('${json['tag_name'] ?? ''}');
      lastChecked = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, lastChecked!.millisecondsSinceEpoch);

      if (_cancelRequested) return false;
      if (release == null || compareVersions(release.version, currentVersion) <= 0) {
        _pendingRelease = null;
        status = UpdateStatus.upToDate;
        notifyListeners();
        return false;
      }

      _pendingRelease = release;
      status = UpdateStatus.available;
      notifyListeners();
      if (autoInstall && autoUpdateEnabled && !_cancelRequested) {
        await downloadAndInstall();
      }
      return true;
    } catch (error) {
      if (_cancelRequested) return false;
      status = UpdateStatus.error;
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> downloadAndInstall() async {
    final release = _pendingRelease;
    if (release == null || _cancelRequested) return;
    status = UpdateStatus.downloading;
    downloadProgress = 0;
    errorMessage = null;
    notifyListeners();

    final client = http.Client();
    _downloadClient = client;
    File? file;
    IOSink? sink;
    try {
      final request = http.Request('GET', release.asset.downloadUrl);
      final response = await client.send(request);
      if (_cancelRequested) return;
      if (response.statusCode != 200) {
        throw HttpException('Update download returned HTTP ${response.statusCode}.');
      }
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}${Platform.pathSeparator}${release.asset.name}');
      sink = file.openWrite();
      final expected = response.contentLength ?? 0;
      var received = 0;
      await for (final bytes in response.stream) {
        if (_cancelRequested) return;
        received += bytes.length;
        sink.add(bytes);
        if (expected > 0) {
          downloadProgress = received / expected;
          notifyListeners();
        }
      }
      await sink.close();
      sink = null;
      if (_cancelRequested) return;

      final expectedHash = release.asset.sha256;
      if (expectedHash != null && expectedHash.isNotEmpty) {
        final actual = sha256.convert(await file.readAsBytes()).toString();
        if (actual.toLowerCase() != expectedHash.toLowerCase()) {
          await file.delete();
          throw const FormatException('Downloaded update failed SHA-256 verification.');
        }
      }

      if (_cancelRequested) return;
      status = UpdateStatus.ready;
      downloadProgress = 1;
      notifyListeners();
      await _install(file);
    } catch (error) {
      if (_cancelRequested) return;
      status = UpdateStatus.error;
      errorMessage = error.toString();
      notifyListeners();
    } finally {
      await sink?.close();
      client.close();
      if (identical(_downloadClient, client)) {
        _downloadClient = null;
      }
      if (_cancelRequested && file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup of a partially downloaded update.
        }
      }
    }
  }

  Future<void> _install(File file) async {
    if (_cancelRequested) return;
    status = UpdateStatus.installing;
    notifyListeners();
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw StateError('Could not open Android installer: ${result.message}');
      }
      exit(0);
    }
    if (Platform.isWindows) {
      await Process.start(
        file.path,
        const ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }
  }

  AppRelease? releaseFromGitHub(Map<String, dynamic> json) {
    final version = _cleanVersion('${json['tag_name'] ?? ''}');
    if (version.isEmpty) return null;
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final pattern = Platform.isAndroid
        ? RegExp(r'^anhpt-v?[0-9]+\.[0-9]+\.[0-9]+\.apk$', caseSensitive: false)
        : RegExp(r'^anhpt-windows-v?[0-9]+\.[0-9]+\.[0-9]+\.exe$', caseSensitive: false);
    for (final asset in assets) {
      final name = '${asset['name'] ?? ''}';
      final url = Uri.tryParse('${asset['browser_download_url'] ?? ''}');
      if (!pattern.hasMatch(name) || url == null) continue;
      final digest = '${asset['digest'] ?? ''}';
      return AppRelease(
        version: version,
        asset: ReleaseAsset(
          name: name,
          downloadUrl: url,
          sha256: digest.startsWith('sha256:') ? digest.substring(7) : null,
        ),
      );
    }
    return null;
  }

  static int compareVersions(String a, String b) {
    final av = _parts(a);
    final bv = _parts(b);
    for (var i = 0; i < 3; i++) {
      final result = av[i].compareTo(bv[i]);
      if (result != 0) return result;
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final clean = _cleanVersion(version);
    final parts = clean.split('.');
    return List<int>.generate(
      3,
      (index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }

  static String _cleanVersion(String version) =>
      version.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
}
