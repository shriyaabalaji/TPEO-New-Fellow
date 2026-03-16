import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/appointment.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';
import '../profile/view_mode_provider.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});

  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage>
    with SingleTickerProviderStateMixin {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Bookings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
              _CompletedTab(
                  appUser: appUser,
                  isDemo: isDemo,
                  demoAppointments: demoAppointments),
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

// ── Upcoming Tab ────────────────────────────────────────────────────────

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
        children: demoAppointments
            .map((a) => _ConsumerBookingCard(
                serviceName: a.title, dateTimeLabel: a.subtitle))
            .toList(),
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
            final scheduled =
                consumerList.where((a) => _isUpcoming(a.status)).toList();

            if (viewingAsProvider && activeId != null && activeId.isNotEmpty) {
              return StreamBuilder(
                stream: fs.streamAppointmentsByProviderProfile(activeId),
                builder: (context, providerSnap) {
                  final providerList = providerSnap.data ?? [];
                  final upcoming =
                      providerList.where((a) => _isUpcoming(a.status)).toList();
                  final pending = upcoming
                      .where((a) =>
                          a.status == 'requested' || a.status == 'pending')
                      .toList();
                  final confirmed = upcoming
                      .where((a) => a.status == 'confirmed')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Filter chips
                      _FilterChips(
                        pendingCount: pending.length,
                        scheduledCount: confirmed.length,
                      ),
                      const SizedBox(height: 12),
                      ...pending.map((a) =>
                          _SPBookingCard(appointment: a, fs: fs, isPending: true)),
                      ...confirmed.map((a) =>
                          _SPBookingCard(appointment: a, fs: fs, isPending: false)),
                      ...scheduled.map((a) => _ConsumerBookingCard(
                            serviceName: a.serviceName,
                            dateTimeLabel: a.slotLabel,
                            price: a.price,
                            status: a.status,
                            consumerUid: a.consumerUid,
                            providerProfileId: a.providerProfileId,
                            fs: fs,
                          )),
                    ],
                  );
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: scheduled
                  .map((a) => _ConsumerBookingCard(
                        serviceName: a.serviceName,
                        dateTimeLabel: a.slotLabel,
                        price: a.price,
                        status: a.status,
                        consumerUid: a.consumerUid,
                        providerProfileId: a.providerProfileId,
                        fs: fs,
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }
}

// ── Filter Chips ────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.pendingCount,
    required this.scheduledCount,
  });

  final int pendingCount;
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip('Pending ($pendingCount)', pendingCount > 0),
        const SizedBox(width: 8),
        _chip('Scheduled ($scheduledCount)', false),
      ],
    );
  }

  Widget _chip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.black : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

// ── SP Booking Card (Provider view) ─────────────────────────────────────

class _SPBookingCard extends StatefulWidget {
  const _SPBookingCard({
    required this.appointment,
    required this.fs,
    required this.isPending,
  });

  final Appointment appointment;
  final FirestoreService fs;
  final bool isPending;

  @override
  State<_SPBookingCard> createState() => _SPBookingCardState();
}

class _SPBookingCardState extends State<_SPBookingCard> {
  bool _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final fs = widget.fs;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service name + pending badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.serviceName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isPending)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Date/time
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.slotLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Appointment Notes expandable
            InkWell(
              onTap: () => setState(() => _notesExpanded = !_notesExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Appointment Notes',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _notesExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
            ),
            if (_notesExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  a.price != null && a.price!.isNotEmpty
                      ? 'Total: ${a.price}'
                      : 'No notes',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),

            const SizedBox(height: 10),

            // Customer info row
            StreamBuilder<UserProfile>(
              stream: fs.streamUserProfile(a.consumerUid),
              builder: (context, snap) {
                final customer = snap.data;
                final name = customer?.displayName ?? 'Customer';
                final photoUrl = customer?.photoUrl;
                final shortName = _shortenName(name);

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shortName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '0 late cancels',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openChat(context, a, fs),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text('Chat',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // Action buttons
            if (widget.isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await fs.updateAppointmentStatus(
                              a.appointmentId, 'confirmed');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Appointment accepted')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')));
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Accept',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await fs.updateAppointmentStatus(
                              a.appointmentId, 'cancelled');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Request declined')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')));
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Decline',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await fs.updateAppointmentStatus(
                          a.appointmentId, 'completed');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Attendance logged')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Log Attendance',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(
      BuildContext context, Appointment a, FirestoreService fs) async {
    try {
      final providerSnap =
          await fs.streamProviderProfile(a.providerProfileId).first;
      final providerOwnerUid = providerSnap?.ownerUid ?? '';
      if (providerOwnerUid.isEmpty) return;
      final chatId = await fs.getOrCreateChat(
        consumerUid: a.consumerUid,
        providerProfileId: a.providerProfileId,
        providerOwnerUid: providerOwnerUid,
      );
      if (context.mounted) context.push('/chat/$chatId');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    }
  }

  String _shortenName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return fullName;
    return '${parts.first} ${parts.last[0]}.';
  }
}

// ── Consumer Booking Card ───────────────────────────────────────────────

class _ConsumerBookingCard extends StatefulWidget {
  const _ConsumerBookingCard({
    required this.serviceName,
    required this.dateTimeLabel,
    this.price,
    this.status,
    this.consumerUid,
    this.providerProfileId,
    this.fs,
  });

  final String serviceName;
  final String dateTimeLabel;
  final String? price;
  final String? status;
  final String? consumerUid;
  final String? providerProfileId;
  final FirestoreService? fs;

  @override
  State<_ConsumerBookingCard> createState() => _ConsumerBookingCardState();
}

class _ConsumerBookingCardState extends State<_ConsumerBookingCard> {
  bool _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.serviceName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.status == 'requested' || widget.status == 'pending')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC5500).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Requested',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFCC5500),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.dateTimeLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _notesExpanded = !_notesExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('Appointment Notes',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(width: 4),
                    Icon(
                      _notesExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
            ),
            if (_notesExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  widget.price != null && widget.price!.isNotEmpty
                      ? 'Total: ${widget.price}'
                      : 'No notes',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.storefront, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Provider',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openChat(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final fs = widget.fs;
    final consumerUid = widget.consumerUid;
    final providerProfileId = widget.providerProfileId;
    if (fs == null || consumerUid == null || providerProfileId == null) {
      context.go('/chat');
      return;
    }
    try {
      final providerSnap =
          await fs.streamProviderProfile(providerProfileId).first;
      final providerOwnerUid = providerSnap?.ownerUid ?? '';
      if (providerOwnerUid.isEmpty) return;
      final chatId = await fs.getOrCreateChat(
        consumerUid: consumerUid,
        providerProfileId: providerProfileId,
        providerOwnerUid: providerOwnerUid,
      );
      if (context.mounted) context.push('/chat/$chatId');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    }
  }
}

// ── Completed Tab ───────────────────────────────────────────────────────

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab(
      {required this.appUser,
      required this.isDemo,
      required this.demoAppointments});

  final AppUser? appUser;
  final bool isDemo;
  final List<DemoAppointment> demoAppointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDemo) {
      if (demoAppointments.isEmpty) return _emptyState(context);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: demoAppointments
            .map((a) => _ConsumerBookingCard(
                serviceName: a.title, dateTimeLabel: a.subtitle))
            .toList(),
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
        if (completed.isEmpty) return _emptyState(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: completed
              .map((a) => _ConsumerBookingCard(
                    serviceName: a.serviceName,
                    dateTimeLabel: a.slotLabel,
                    price: a.price,
                    consumerUid: a.consumerUid,
                    providerProfileId: a.providerProfileId,
                    fs: fs,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No previous bookings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Completed appointments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
