import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_calendar_service.dart';

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});
