import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/services/ota_update_service.dart';

void main() {
  group('OtaUpdateService.isVersionNewer', () {
    test('returns true when latest is major ahead', () {
      expect(OtaUpdateService.isVersionNewer('2.0', '1.7.0'), true);
      expect(OtaUpdateService.isVersionNewer('2.0.0', '1.9.9'), true);
    });

    test('returns true when latest is minor ahead (X.Y format)', () {
      expect(OtaUpdateService.isVersionNewer('1.8', '1.7.0'), true);
      expect(OtaUpdateService.isVersionNewer('1.10', '1.9.5'), true);
    });

    test('returns true when latest is patch ahead', () {
      expect(OtaUpdateService.isVersionNewer('1.7.1', '1.7.0'), true);
    });

    test('returns false when versions are equal', () {
      expect(OtaUpdateService.isVersionNewer('1.7.0', '1.7.0'), false);
      expect(OtaUpdateService.isVersionNewer('1.7', '1.7.0'), false);
      expect(OtaUpdateService.isVersionNewer('1.7.0', '1.7'), false);
    });

    test('returns false when latest is older', () {
      expect(OtaUpdateService.isVersionNewer('1.6', '1.7.0'), false);
      expect(OtaUpdateService.isVersionNewer('1.6.9', '1.7.0'), false);
    });

    test('handles v prefix in tag', () {
      expect(OtaUpdateService.isVersionNewer('v1.8', '1.7.0'), true);
      expect(OtaUpdateService.isVersionNewer('v2.0.0', '1.9.9'), true);
    });

    test('handles X.Y tag vs X.Y.Z current', () {
      expect(OtaUpdateService.isVersionNewer('1.8', '1.7.5'), true);
      expect(OtaUpdateService.isVersionNewer('1.7', '1.7.5'), false);
    });

    test('handles single digit versions', () {
      expect(OtaUpdateService.isVersionNewer('2', '1.9.9'), true);
      expect(OtaUpdateService.isVersionNewer('1', '1.0.0'), false);
    });
  });

  group('OtaCheckResult sealed class', () {
    test('OtaUpToDate stores currentVersion', () {
      final result = OtaUpToDate('1.7.0');
      expect(result.currentVersion, '1.7.0');
    });

    test('OtaUpdateAvailable stores all fields', () {
      final result = OtaUpdateAvailable(
        latestVersion: '1.8.0',
        releaseNotes: 'Bug fixes',
        downloadUrl: 'https://example.com/app.apk',
        publishedAt: '2026-06-01',
      );
      expect(result.latestVersion, '1.8.0');
      expect(result.releaseNotes, 'Bug fixes');
      expect(result.downloadUrl, 'https://example.com/app.apk');
      expect(result.publishedAt, '2026-06-01');
    });

    test('OtaCheckError stores message', () {
      final result = OtaCheckError('Network error');
      expect(result.message, 'Network error');
    });

    test('pattern matching works correctly', () {
      final results = <OtaCheckResult>[
        OtaUpToDate('1.7.0'),
        OtaUpdateAvailable(
          latestVersion: '1.8.0',
          releaseNotes: '',
          downloadUrl: 'https://example.com/app.apk',
          publishedAt: '',
        ),
        OtaCheckError('error'),
      ];

      expect(results[0], isA<OtaUpToDate>());
      expect(results[1], isA<OtaUpdateAvailable>());
      expect(results[2], isA<OtaCheckError>());
    });
  });
}
