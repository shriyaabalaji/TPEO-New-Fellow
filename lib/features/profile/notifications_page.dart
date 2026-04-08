import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/subpage_app_bar.dart';
import 'notifications_preferences_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
