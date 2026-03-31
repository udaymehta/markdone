import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

const _tzAliases = <String, String>{
  'Asia/Calcutta': 'Asia/Kolkata',
  'US/Eastern': 'America/New_York',
  'US/Central': 'America/Chicago',
  'US/Mountain': 'America/Denver',
  'US/Pacific': 'America/Los_Angeles',
  'US/Hawaii': 'Pacific/Honolulu',
  'US/Alaska': 'America/Anchorage',
  'US/Arizona': 'America/Phoenix',
  'Canada/Eastern': 'America/Toronto',
  'Canada/Central': 'America/Winnipeg',
  'Canada/Pacific': 'America/Vancouver',
  'Europe/Kiev': 'Europe/Kyiv',
  'Pacific/Samoa': 'Pacific/Pago_Pago',
};

tz.Location resolveTimezoneLocation(String identifier) {
  try {
    return tz.getLocation(identifier);
  } catch (_) {
    final alias = _tzAliases[identifier];
    if (alias != null) {
      return tz.getLocation(alias);
    }
    rethrow;
  }
}

bool _tzInitialized = false;

Future<void> initializeTimezone() async {
  if (_tzInitialized) return;

  tz_data.initializeTimeZones();
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(resolveTimezoneLocation(tzInfo.identifier));
  } catch (e) {
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}
  }
  _tzInitialized = true;
}
