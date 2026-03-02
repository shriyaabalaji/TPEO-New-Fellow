import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/appointment.dart';
import '../../models/availability_slot.dart';
import '../../utils/availability_options.dart';
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
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
              _UpcomingTab(
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

bool _isUpcoming(String status) =>
    status == 'requested' || status == 'pending' || status == 'confirmed';

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab({
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
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...demoAppointments.map((a) => _BookingCard(serviceName: a.title, dateTimeLabel: a.subtitle)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/find'),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Book now!'),
          ),
        ],
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
            final scheduled = consumerList.where((a) => _isUpcoming(a.status)).toList();
            if (viewingAsProvider && activeId != null && activeId.isNotEmpty) {
              return StreamBuilder(
                stream: fs.streamAppointmentsByProviderProfile(activeId),
                builder: (context, providerSnap) {
                  final providerList = providerSnap.data ?? [];
                  final upcoming = providerList.where((a) => _isUpcoming(a.status)).toList();
                  final requestedFirst = [
                    ...upcoming.where((a) => a.status == 'requested' || a.status == 'pending'),
                    ...upcoming.where((a) => a.status == 'confirmed'),
                  ];
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...requestedFirst.map((a) => _ProviderAppointmentCard(appointment: a, fs: fs)),
                      ...scheduled.map((a) => _BookingCard(
                            serviceName: a.serviceName,
                            dateTimeLabel: a.slotLabel,
                            price: a.price,
                            status: a.status,
                          )),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/find'),
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Book now!'),
                      ),
                    ],
                  );
                },
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...scheduled.map((a) => _BookingCard(
                      serviceName: a.serviceName,
                      dateTimeLabel: a.slotLabel,
                      price: a.price,
                      status: a.status,
                    )),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/find'),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Book now!'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BookingCard extends StatefulWidget {
  const _BookingCard({
    required this.serviceName,
    required this.dateTimeLabel,
    this.price,
    this.status,
  });

  final String serviceName;
  final String dateTimeLabel;
  final String? price;
  final String? status;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  var _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    const providerName = 'Provider';
    final initial = providerName.isNotEmpty ? providerName.substring(0, 1).toUpperCase() : '?';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.serviceName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showBookingMenu(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.dateTimeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                ),
              ],
            ),
            if (widget.status == 'requested' || widget.status == 'pending') ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC5500).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCC5500), width: 1),
                  ),
                  child: Text(
                    'Requested',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFCC5500),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _notesExpanded = !_notesExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Appointment Notes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 4),
                    Icon(_notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22),
                  ],
                ),
              ),
            ),
            if (_notesExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.price != null && widget.price!.isNotEmpty ? 'Total: ${widget.price}' : 'No notes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    providerName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Contact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderAppointmentCard extends StatefulWidget {
  const _ProviderAppointmentCard({required this.appointment, required this.fs});

  final Appointment appointment;
  final FirestoreService fs;

  @override
  State<_ProviderAppointmentCard> createState() => _ProviderAppointmentCardState();
}

class _ProviderAppointmentCardState extends State<_ProviderAppointmentCard> {
  late String _serviceName;
  late String _slotLabel;
  late String _price;

  @override
  void initState() {
    super.initState();
    _serviceName = widget.appointment.serviceName;
    _slotLabel = widget.appointment.slotLabel;
    _price = widget.appointment.price ?? '';
  }

  @override
  void didUpdateWidget(covariant _ProviderAppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointment.appointmentId != widget.appointment.appointmentId ||
        oldWidget.appointment.updatedAt != widget.appointment.updatedAt) {
      _serviceName = widget.appointment.serviceName;
      _slotLabel = widget.appointment.slotLabel;
      _price = widget.appointment.price ?? '';
    }
  }

  bool get _isRequested =>
      widget.appointment.status == 'requested' || widget.appointment.status == 'pending';

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final fs = widget.fs;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isRequested)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCC5500).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Requested',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFCC5500),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        )
                      else
                        Text(
                          'Confirmed',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _serviceName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        _slotLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                      ),
                      if (_price.isNotEmpty)
                        Text(
                          _price,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (_isRequested)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditDialog(context, fs),
                  ),
              ],
            ),
            if (_isRequested) ...[
              const SizedBox(height: 12),
              Row(
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
                        if (_serviceName != appointment.serviceName || _slotLabel != appointment.slotLabel || _price != (appointment.price ?? '')) {
                          await fs.updateAppointment(
                            appointmentId: appointment.appointmentId,
                            serviceName: _serviceName,
                            slotLabel: _slotLabel,
                            price: _price.isEmpty ? null : _price,
                          );
                        }
                        await fs.updateAppointmentStatus(appointment.appointmentId, 'confirmed');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment confirmed')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, FirestoreService fs) async {
    final serviceCtrl = TextEditingController(text: _serviceName);
    final priceCtrl = TextEditingController(text: _price);
    var selectedSlotLabel = _slotLabel;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(labelText: 'Service'),
                ),
                const SizedBox(height: 16),
                Text('Date & time', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                StreamBuilder<List<AvailabilitySlot>>(
                  stream: fs.streamAvailability(widget.appointment.providerProfileId),
                  builder: (context, availSnap) {
                    final slots = availSnap.data ?? [];
                    final options = expandSlotsToTimeOptions(slots);
                    if (options.isEmpty) {
                      return Text(
                        selectedSlotLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    final byDay = <String, List<TimeOption>>{};
                    for (final o in options) {
                      byDay.putIfAbsent(o.dayName, () => []).add(o);
                    }
                    final dayOrder = dayNames.where((d) => byDay.containsKey(d)).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: dayOrder.map((day) {
                        final dayOptions = byDay[day]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: dayOptions.map((o) {
                                  final isSelected = selectedSlotLabel == o.slotLabel;
                                  return ChoiceChip(
                                    label: Text(o.timeLabel),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setDialogState(() => selectedSlotLabel = o.slotLabel);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final newService = serviceCtrl.text.trim();
                final newPrice = priceCtrl.text.trim();
                if (newService.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await fs.updateAppointment(
                    appointmentId: widget.appointment.appointmentId,
                    serviceName: newService,
                    slotLabel: selectedSlotLabel,
                    price: newPrice.isEmpty ? null : newPrice,
                  );
                  if (mounted) {
                    setState(() {
                      _serviceName = newService;
                      _slotLabel = selectedSlotLabel;
                      _price = newPrice;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
      if (demoAppointments.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No previous bookings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed appointments will appear here once you\'ve visited.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/find'),
                  child: const Text('Explore Services'),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: demoAppointments.map((a) => _BookingCard(serviceName: a.title, dateTimeLabel: a.subtitle)).toList(),
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
        if (completed.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No previous bookings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed appointments will appear here once you\'ve visited.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/find'),
                    child: const Text('Explore Services'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: completed
              .map((a) => _BookingCard(
                    serviceName: a.serviceName,
                    dateTimeLabel: a.slotLabel,
                    price: a.price,
                  ))
              .toList(),
        );
      },
    );
  }
}
