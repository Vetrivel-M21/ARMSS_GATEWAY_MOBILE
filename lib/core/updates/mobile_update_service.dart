import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/gateway_api_client.dart';

String? _cachedAppVersion;

/// Retrieves the current application version dynamically from pubspec.yaml
/// (via PackageInfo with fallback to asset pubspec.yaml parsing).
Future<String> getCurrentAppVersion() async {
  if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
    return _cachedAppVersion!;
  }

  // 1. Primary: PackageInfo from platform
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) {
      _cachedAppVersion = info.version;
      return _cachedAppVersion!;
    }
  } catch (_) {}

  // 2. Fallback: Parse pubspec.yaml from asset bundle
  try {
    final yamlString = await rootBundle.loadString('pubspec.yaml');
    final match = RegExp(
      r'^version:\s*([^\s+]+)',
      multiLine: true,
    ).firstMatch(yamlString);
    if (match != null && match.group(1) != null) {
      _cachedAppVersion = match.group(1)!.trim();
      return _cachedAppVersion!;
    }
  } catch (_) {}

  return _cachedAppVersion ?? '1.1.4';
}

/// For synchronous compatibility where currentAppVersion is referenced
String get currentAppVersion => _cachedAppVersion ?? '1.1.4';

class MobileUpdateInfo {
  final String version;
  final String url;
  final String sha256;
  final String? releaseNotes;

  const MobileUpdateInfo({
    required this.version,
    required this.url,
    required this.sha256,
    this.releaseNotes,
  });
}

class MobileUpdateService {
  static const _installerChannel =
      MethodChannel('com.armss.armss_gateway_mobile/app_installer');

  /// Checks if a newer mobile app version is available on the gateway server.
  Future<MobileUpdateInfo?> check() async {
    try {
      final currentVersion = await getCurrentAppVersion();
      final uri = Uri.parse(
        '${GatewayApiClient.apiBaseUrl}/app/mobile-update',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        // Fallback to /app/update?platform=android if /app/mobile-update is not routed
        final fallbackUri = Uri.parse(
          '${GatewayApiClient.apiBaseUrl}/app/update?platform=android',
        );
        final fallbackResp =
            await http.get(fallbackUri).timeout(const Duration(seconds: 8));
        if (fallbackResp.statusCode != 200) return null;
        return _parseEnvelope(fallbackResp.body, currentVersion);
      }

      return _parseEnvelope(response.body, currentVersion);
    } catch (e) {
      debugPrint('[MobileUpdateService] Update check error: $e');
      return null;
    }
  }

  MobileUpdateInfo? _parseEnvelope(String body, String currentVersion) {
    try {
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final data = envelope['data'] as Map<String, dynamic>?;
      if (envelope['success'] != true || data?['available'] != true) {
        return null;
      }

      final version = data?['version'] as String?;
      var url = data?['url'] as String?;
      final hash = data?['sha256'] as String? ?? '';

      if (version == null || url == null || !_isNewer(version, currentVersion)) {
        return null;
      }

      // If url is relative, make it absolute against apiBaseUrl
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        final base = GatewayApiClient.apiBaseUrl.replaceAll('/api/v1', '');
        url = '$base${url.startsWith('/') ? '' : '/'}$url';
      }

      // Hard safeguard: never download a Windows executable on mobile
      if (url.toLowerCase().endsWith('.exe') || url.toLowerCase().contains('/app/download')) {
        debugPrint('[MobileUpdateService] Safeguard: rejected non-mobile installer URL: $url');
        return null;
      }


      return MobileUpdateInfo(
        version: version,
        url: url,
        sha256: hash,
        releaseNotes: data?['release_notes'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks whether Android has granted permission to install unknown apps.
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (e) {
      debugPrint('[MobileUpdateService] canRequestPackageInstalls error: $e');
      return true;
    }
  }

  /// Opens the Android system settings page to enable app installation from this source.
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _installerChannel
          .invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('[MobileUpdateService] openSettings error: $e');
      return false;
    }
  }

  /// Downloads the APK, verifies SHA-256 integrity, and triggers native installation.
  Future<void> downloadAndInstall(
    MobileUpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(update.url));
      final response = await client.send(request).timeout(
            const Duration(minutes: 10),
          );

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download update (HTTP ${response.statusCode})',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File(
        '${tempDir.path}/ARMSS_Gateway_${update.version}.apk',
      );

      // Clean up previous partial downloads if any
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      final bytesBuilder = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        bytesBuilder.add(chunk);
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      // Integrity Check: verify SHA-256
      if (update.sha256.isNotEmpty) {
        final downloadedBytes = bytesBuilder.takeBytes();
        final calculatedSha256 =
            sha256.convert(downloadedBytes).toString().toLowerCase();
        if (calculatedSha256 != update.sha256.toLowerCase()) {
          if (await apkFile.exists()) {
            await apkFile.delete();
          }
          throw const HttpException(
            'Security validation failed: SHA-256 integrity mismatch. Download aborted.',
          );
        }
      }

      // Trigger native package installer
      if (Platform.isAndroid) {
        await _installerChannel.invokeMethod('installApk', {
          'filePath': apkFile.path,
        });
      }
    } finally {
      client.close();
    }
  }

  bool _isNewer(String candidate, String current) {
    List<int> parts(String value) {
      final clean = value.split('+').first;
      return clean.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    }

    final next = parts(candidate);
    final installed = parts(current);
    for (var index = 0; index < 3; index++) {
      final nextPart = index < next.length ? next[index] : 0;
      final installedPart = index < installed.length ? installed[index] : 0;
      if (nextPart != installedPart) return nextPart > installedPart;
    }
    return false;
  }
}
