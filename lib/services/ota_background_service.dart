import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'ota_update_service.dart';

const String _otaDismissedVersionKey = 'ota_dismissed_version';
const String _otaPendingVersionKey = 'ota_pending_version';
const String _otaPendingDownloadUrlKey = 'ota_pending_download_url';
const String _otaPendingReleaseNotesKey = 'ota_pending_release_notes';

@pragma('vm:entry-point')
void otaBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    final result = await OtaUpdateService.checkForUpdate();
    if (result is! OtaUpdateAvailable) return true;

    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_otaDismissedVersionKey);
    if (result.latestVersion == dismissedVersion) return true;

    await prefs.setString(_otaPendingVersionKey, result.latestVersion);
    await prefs.setString(_otaPendingDownloadUrlKey, result.downloadUrl);
    await prefs.setString(_otaPendingReleaseNotesKey, result.releaseNotes);

    final notif = NotificationService();
    await notif.init();
    await notif.showInstant(
      title: 'MarkDone! v${result.latestVersion} available',
      body: 'Tap to download and install',
    );

    return true;
  });
}
