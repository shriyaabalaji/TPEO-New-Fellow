import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyPush = 'notif_push';
const _keyAppointmentReminders = 'notif_appointment_reminders';
const _keyNewMessages = 'notif_new_messages';

class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.appointmentRemindersEnabled = true,
    this.newMessagesEnabled = false,
  });

  final bool pushEnabled;
  final bool appointmentRemindersEnabled;
  final bool newMessagesEnabled;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? appointmentRemindersEnabled,
    bool? newMessagesEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      appointmentRemindersEnabled: appointmentRemindersEnabled ?? this.appointmentRemindersEnabled,
      newMessagesEnabled: newMessagesEnabled ?? this.newMessagesEnabled,
    );
  }
}

final notificationsPreferencesProvider = StateNotifierProvider<NotificationsPreferencesNotifier, AsyncValue<NotificationPreferences>>((ref) {
  return NotificationsPreferencesNotifier();
});

class NotificationsPreferencesNotifier extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationsPreferencesNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      state = AsyncValue.data(NotificationPreferences(
        pushEnabled: prefs.getBool(_keyPush) ?? true,
        appointmentRemindersEnabled: prefs.getBool(_keyAppointmentReminders) ?? true,
        newMessagesEnabled: prefs.getBool(_keyNewMessages) ?? false,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setPushEnabled(bool value) async {
    state.whenOrNull(
      data: (prefs) async {
        final next = prefs.copyWith(pushEnabled: value);
        state = AsyncValue.data(next);
        final prefsStorage = await _prefs();
        await prefsStorage.setBool(_keyPush, value);
      },
    );
  }

  Future<void> setAppointmentRemindersEnabled(bool value) async {
    state.whenOrNull(
      data: (prefs) async {
        final next = prefs.copyWith(appointmentRemindersEnabled: value);
        state = AsyncValue.data(next);
        final prefsStorage = await _prefs();
        await prefsStorage.setBool(_keyAppointmentReminders, value);
      },
    );
  }

  Future<void> setNewMessagesEnabled(bool value) async {
    state.whenOrNull(
      data: (prefs) async {
        final next = prefs.copyWith(newMessagesEnabled: value);
        state = AsyncValue.data(next);
        final prefsStorage = await _prefs();
        await prefsStorage.setBool(_keyNewMessages, value);
      },
    );
  }
}
