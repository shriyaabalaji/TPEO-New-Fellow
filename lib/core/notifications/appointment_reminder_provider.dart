import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/profile/notifications_preferences_provider.dart';
import '../../features/profile/provider_account_controller.dart';
import '../../models/appointment.dart';
import 'notification_service.dart';

/// Streams the current user's appointments (empty list when logged out).
final _consumerAppointmentsStreamProvider =
    StreamProvider<List<Appointment>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final fs = ref.watch(firestoreServiceProvider);
  if (uid == null || fs == null) return const Stream.empty();
  return fs.streamAppointmentsByConsumer(uid);
});

/// Watch this in the app root to keep appointment reminders in sync.
/// It observes appointments + preferences and schedules/cancels as needed.
final appointmentReminderProvider = Provider<void>((ref) {
  final prefsAsync = ref.watch(notificationsPreferencesProvider);
  final remindersEnabled =
      prefsAsync.valueOrNull?.appointmentRemindersEnabled ?? true;

  ref.listen<AsyncValue<List<Appointment>>>(
    _consumerAppointmentsStreamProvider,
    (_, next) {
      if (!remindersEnabled) {
        NotificationService.instance.cancelAll();
        return;
      }
      NotificationService.instance.rescheduleAll(next.valueOrNull ?? []);
    },
    fireImmediately: true,
  );
});
