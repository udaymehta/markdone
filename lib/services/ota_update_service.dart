import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

sealed class OtaCheckResult {
  const OtaCheckResult();
}

class OtaUpToDate extends OtaCheckResult {
  final String currentVersion;
  const OtaUpToDate(this.currentVersion);
}

class OtaUpdateAvailable extends OtaCheckResult {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String publishedAt;
  const OtaUpdateAvailable({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.publishedAt,
  });
}

class OtaCheckError extends OtaCheckResult {
  final String message;
  const OtaCheckError(this.message);
}

List<int> _parseVersion(String v) {
  v = v.replaceFirst(RegExp(r'^v'), '').trim();
  final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (parts.length < 3) { parts.add(0); }
  return parts;
}

bool _isNewerVersion(String latestTag, String currentVersion) {
  final latest = _parseVersion(latestTag);
  final current = _parseVersion(currentVersion);
  for (int i = 0; i < 3; i++) {
    if (latest[i] > current[i]) return true;
    if (latest[i] < current[i]) return false;
  }
  return false;
}

class OtaUpdateService {
  static const String _repoOwner = 'atanhx';
  static const String _repoName = 'markdone';
  static const String _githubApiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  static Future<OtaCheckResult> checkForUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentVersion = pkg.version;

      final uri = Uri.parse(_githubApiUrl);
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 403) {
        return const OtaCheckError(
          'GitHub API rate limit reached. Try again later.',
        );
      }
      if (response.statusCode != 200) {
        return OtaCheckError(
          'Failed to check for updates (HTTP ${response.statusCode}).',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String).trim();
      final tag = tagName.replaceFirst(RegExp(r'^v'), '');

      if (!_isNewerVersion(tag, currentVersion)) {
        return OtaUpToDate(currentVersion);
      }

      final abi = await _detectAbi();
      final assets = data['assets'] as List;
      final apkName = 'app-$abi-release.apk';
      Map<String, dynamic>? asset;
      for (final a in assets) {
        if ((a['name'] as String) == apkName) {
          asset = a as Map<String, dynamic>;
          break;
        }
      }

      if (asset == null) {
        return OtaCheckError(
          'No APK found for your device architecture ($abi).\n'
          'Open the release page to manually download.',
        );
      }

      return OtaUpdateAvailable(
        latestVersion: tag,
        releaseNotes: (data['body'] as String?) ?? '',
        downloadUrl: asset['browser_download_url'] as String,
        publishedAt: (data['published_at'] as String?) ?? '',
      );
    } catch (e) {
      return OtaCheckError('No internet connection. Please try again later.');
    }
  }

  static Future<String> downloadApk({
    required String url,
    required String version,
    required void Function(double fraction) onProgress,
  }) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/ota');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/markdone_v$version.apk');

    if (await file.exists()) return file.path;

    _cleanupOldApks(dir, version);

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    final total = response.contentLength ?? -1;

    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return file.path;
  }

  static Future<void> _cleanupOldApks(Directory dir, String currentVersion) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.apk')) {
          final name = entity.uri.pathSegments.last;
          if (!name.contains('_v$currentVersion.')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }

  static Future<String> _detectAbi() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;
      if (abis.isNotEmpty) {
        final abi = abis.first;
        if (abi.contains('arm64')) return 'arm64-v8a';
        if (abi.contains('armeabi-v7a')) return 'armeabi-v7a';
        if (abi.contains('x86_64')) return 'x86_64';
        if (abi.contains('x86')) return 'x86_64';
      }
    } catch (_) {}
    return 'arm64-v8a';
  }

  static bool isVersionNewer(String latestTag, String currentVersion) =>
      _isNewerVersion(latestTag, currentVersion);

  static Future<String> getCurrentVersion() async {
    final pkg = await PackageInfo.fromPlatform();
    return pkg.version;
  }
}
