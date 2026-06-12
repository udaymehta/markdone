import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/settings/widgets/ota_update_dialog.dart';

const String _otaPendingVersionKey = 'ota_pending_version';
const String _otaPendingDownloadUrlKey = 'ota_pending_download_url';
const String _otaPendingReleaseNotesKey = 'ota_pending_release_notes';

class OtaPayloadHandler {
  static Future<void> handlePendingUpdate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString(_otaPendingVersionKey);
    if (version == null) return;

    final downloadUrl = prefs.getString(_otaPendingDownloadUrlKey)!;
    final releaseNotes =
        prefs.getString(_otaPendingReleaseNotesKey) ?? '';

    await prefs.remove(_otaPendingVersionKey);
    await prefs.remove(_otaPendingDownloadUrlKey);
    await prefs.remove(_otaPendingReleaseNotesKey);

    if (context.mounted) {
      showOtaUpdateDialog(
        context,
        initialData: OtaUpdateDialogData(
          latestVersion: version,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          publishedAt: '',
        ),
      );
    }
  }
}
