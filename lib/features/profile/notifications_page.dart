import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/ui/subpage_app_bar.dart';
import 'notifications_preferences_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(notificationsPreferencesProvider);
    final notifier = ref.read(notificationsPreferencesProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(context, title: 'Notifications'),
      body: prefsState.when(
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Push notifications'),
              value: prefs.pushEnabled,
              onChanged: (value) => notifier.setPushEnabled(value),
            ),
            SwitchListTile(
              title: const Text('Appointment reminders'),
              value: prefs.appointmentRemindersEnabled,
              onChanged: (value) => notifier.setAppointmentRemindersEnabled(value),
            ),
            SwitchListTile(
              title: const Text('New messages'),
              value: prefs.newMessagesEnabled,
              onChanged: (value) => notifier.setNewMessagesEnabled(value),
            ),
            const Divider(height: 32),
            ListTile(
              title: const Text('Send test notification'),
              subtitle: const Text('Fires in 10 seconds — lock your screen to see it'),
              trailing: const Icon(Icons.notifications_active_outlined),
              onTap: () async {
                await NotificationService.instance.scheduleTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification scheduled for 10 seconds from now')),
                  );
                }
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
