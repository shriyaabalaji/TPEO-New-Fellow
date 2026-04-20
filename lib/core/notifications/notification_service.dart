import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/appointment.dart';
import '../../utils/slot_label_parser.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  int _notifId(String appointmentId) => appointmentId.hashCode.abs() % 100000;

  Future<void> scheduleAppointmentReminder(Appointment appointment) async {
    final range = parseSlotLabelToRange(appointment.slotLabel);
    if (range == null) return;
    final reminderTime = range.start.subtract(const Duration(hours: 1));
    if (!reminderTime.isAfter(DateTime.now())) return;
    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);
    await _plugin.zonedSchedule(
      _notifId(appointment.appointmentId),
      'Upcoming Appointment',
      '${appointment.serviceName} in 1 hour — ${appointment.slotLabel}',
      tzTime,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'appointment_reminders',
          'Appointment Reminders',
          channelDescription: 'Reminders 1 hour before your appointments',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Fires a test notification after [delay] to verify the setup works.
  Future<void> scheduleTestNotification({Duration delay = const Duration(seconds: 10)}) async {
    final tzTime = tz.TZDateTime.from(DateTime.now().add(delay), tz.local);
    await _plugin.zonedSchedule(
      999999,
      'Test Notification',
      'Notifications are working!',
      tzTime,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        android: AndroidNotificationDetails(
          'appointment_reminders',
          'Appointment Reminders',
          channelDescription: 'Reminders 1 hour before your appointments',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelAppointmentReminder(String appointmentId) async {
    await _plugin.cancel(_notifId(appointmentId));
  }

  Future<void> rescheduleAll(List<Appointment> appointments) async {
    await _plugin.cancelAll();
    for (final appt in appointments) {
      if (appt.status == 'accepted' || appt.status == 'confirmed') {
        await scheduleAppointmentReminder(appt);
      }
    }
  }
}
