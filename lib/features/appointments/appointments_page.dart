import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/appointment.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import '../profile/view_mode_provider.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});

  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewingAsProvider = ref.watch(viewingAsProviderProvider);
    final effectiveUser = ref.watch(effectiveUserProvider);
    final demoAppointments = ref.watch(demoAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scheduled'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          final isDemo = appUser?.isDemo ?? false;
          return TabBarView(
            controller: _tabController,
            children: [
              _ScheduledTab(
                appUser: appUser,
                viewingAsProvider: viewingAsProvider,
                isDemo: isDemo,
                demoAppointments: demoAppointments,
              ),
              _CompletedTab(appUser: appUser, isDemo: isDemo, demoAppointments: demoAppointments),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading')),
      ),
    );
  }
}

class _ScheduledTab extends ConsumerWidget {
  const _ScheduledTab({
    required this.appUser,
    required this.viewingAsProvider,
    required this.isDemo,
    required this.demoAppointments,
  });

  final AppUser? appUser;
  final bool viewingAsProvider;
  final bool isDemo;
  final List<DemoAppointment> demoAppointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDemo) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your appointments (demo)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...demoAppointments.map((a) => _AppointmentCard(title: a.title, subtitle: a.subtitle)),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => context.go('/find'),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Book now!'),
            ),
          ],
        ),
      );
    }
    final fs = ref.watch(firestoreServiceProvider);
    if (appUser == null || fs == null) {
      return const Center(child: Text('Sign in to see appointments.'));
    }
    return StreamBuilder(
      stream: fs.streamUserProfile(appUser!.uid),
      builder: (context, userSnap) {
        final activeId = userSnap.data?.activeProviderProfileId;
        return StreamBuilder(
          stream: fs.streamAppointmentsByConsumer(appUser!.uid),
          builder: (context, consumerSnap) {
            final consumerList = consumerSnap.data ?? [];
            final scheduled = consumerList.where((a) => a.status == 'pending' || a.status == 'confirmed').toList();
            if (viewingAsProvider && activeId != null && activeId.isNotEmpty) {
              return StreamBuilder(
                stream: fs.streamAppointmentsByProviderProfile(activeId),
                builder: (context, providerSnap) {
                  final providerList = providerSnap.data ?? [];
                  final providerScheduled = providerList.where((a) => a.status == 'pending' || a.status == 'confirmed').toList();
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (providerScheduled.isNotEmpty) ...[
                          Text('Incoming (as provider)', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          ...providerScheduled.map((a) => _ProviderAppointmentCard(appointment: a, fs: fs)),
                          const SizedBox(height: 24),
                        ],
                        Text('Your appointments', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...scheduled.map((a) => _AppointmentCard(
                              title: a.serviceName,
                              subtitle: a.slotLabel,
                              price: a.price,
                            )),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/find'),
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Book now!'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your appointments', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...scheduled.map((a) => _AppointmentCard(
                        title: a.serviceName,
                        subtitle: a.slotLabel,
                        price: a.price,
                      )),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/find'),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Book now!'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.title,
    required this.subtitle,
    this.price,
  });

  final String title;
  final String subtitle;
  final String? price;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: price != null && price!.isNotEmpty
            ? Text(price!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ProviderAppointmentCard extends StatelessWidget {
  const _ProviderAppointmentCard({required this.appointment, required this.fs});

  final Appointment appointment;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final isPending = appointment.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(appointment.serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${appointment.slotLabel} · ${appointment.status}'),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await fs.updateAppointmentStatus(appointment.appointmentId, 'cancelled');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    child: Text('Decline', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await fs.updateAppointmentStatus(appointment.appointmentId, 'confirmed');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request accepted')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatefulWidget {
  const _PendingRequestCard({required this.expandable});

  final bool expandable;

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: const Text('Requested appointment'),
            subtitle: const Text('Service · Date'),
            trailing: widget.expandable
                ? IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  )
                : null,
          ),
          if (widget.expandable && _expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Save')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () {}, child: const Text('Decline')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab({required this.appUser, required this.isDemo, required this.demoAppointments});

  final AppUser? appUser;
  final bool isDemo;
  final List<DemoAppointment> demoAppointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDemo) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Completed (demo)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...demoAppointments.map((a) => _AppointmentCard(title: a.title, subtitle: a.subtitle)),
        ],
      );
    }
    final fs = ref.watch(firestoreServiceProvider);
    if (appUser == null || fs == null) {
      return const Center(child: Text('Sign in to see appointments.'));
    }
    return StreamBuilder(
      stream: fs.streamAppointmentsByConsumer(appUser!.uid),
      builder: (context, snap) {
        final list = snap.data ?? [];
        final completed = list.where((a) => a.status == 'completed').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Completed', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...completed.map((a) => _AppointmentCard(title: a.serviceName, subtitle: a.slotLabel, price: a.price)),
          ],
        );
      },
    );
  }
}
