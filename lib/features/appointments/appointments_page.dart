import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/calendar/calendar_providers.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/ui/page_title.dart';
import '../../models/appointment.dart';
import '../../models/provider_profile.dart';
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
        title: primaryPageTitle('Bookings'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: const Color(0xFF1A1A1A),
                labelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 34 / 2.1),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 34 / 2.1),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: const Color(0xFFE0E0E0),
                dividerHeight: 3,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Color(0xFF2B2B2B), width: 3.2),
                  insets: EdgeInsets.zero,
                ),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
          ),
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
                  viewingAsProvider: viewingAsProvider,
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

enum _CustomerBookingFilter { all, scheduled, pending }

final customerBookingFilterProvider =
    StateProvider<_CustomerBookingFilter>((ref) => _CustomerBookingFilter.all);

bool _isWithinLastDays(DateTime? dt, int days) {
  if (dt == null) return false;
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return dt.isAfter(cutoff);
}

bool _isProviderCompletedOutcome(Appointment a) {
  if (a.status == 'completed' || a.status == 'no_show' || a.status == 'late_cancel') {
    return true;
  }
  if (a.status == 'cancelled') {
    return _isWithinLastDays(a.updatedAt ?? a.createdAt, 5);
  }
  return false;
}

/// Design: service title and person/provider names use regular weight, not bold.
const _kAppointmentTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w400,
  color: Color(0xFF1A1A1A),
  height: 1.0,
);

const _kPersonNameStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w400,
  color: Color(0xFF1A1A1A),
  height: 1.2,
);

const _kNotesRowLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: Color(0xFF1A1A1A),
);

class _StatusPillStyle {
  const _StatusPillStyle({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;
}

_StatusPillStyle _statusStyle(String? status) {
  switch (status) {
    case 'requested':
    case 'pending':
      return const _StatusPillStyle(
        label: 'Pending',
        bg: Color(0xFFFFF2CC),
        fg: Color(0xFF8A6400),
        icon: Icons.schedule,
      );
    case 'confirmed':
      return const _StatusPillStyle(
        label: 'Confirmed',
        bg: Color(0xFFDDEBFF),
        fg: Color(0xFF1D4D8F),
        icon: Icons.check_circle,
      );
    case 'completed':
      return const _StatusPillStyle(
        label: 'Attended',
        bg: Color(0xFFE5F6E7),
        fg: Color(0xFF2E7D32),
        icon: Icons.check_circle,
      );
    case 'no_show':
      return const _StatusPillStyle(
        label: 'No Show',
        bg: Color(0xFFFFF4CC),
        fg: Color(0xFF8C6D00),
        icon: Icons.warning_amber_rounded,
      );
    case 'late_cancel':
      return const _StatusPillStyle(
        label: 'Late Cancel (>24h)',
        bg: Color(0xFFFFE9C7),
        fg: Color(0xFF9C5D00),
        icon: Icons.info_outline,
      );
    case 'cancelled':
      return const _StatusPillStyle(
        label: 'Cancelled',
        bg: Color(0xFFFFE3E3),
        fg: Color(0xFFA32121),
        icon: Icons.close,
      );
    default:
      return const _StatusPillStyle(
        label: 'Pending',
        bg: Color(0xFFFFF2CC),
        fg: Color(0xFF8A6400),
        icon: Icons.schedule,
      );
  }
}

Future<void> _showLeaveFeedbackSheet(
  BuildContext context, {
  required FirestoreService fs,
  required String appointmentId,
  required String consumerUid,
}) async {
  final commentCtrl = TextEditingController();
  var selected = 5;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Rate your experience',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final starIndex = i + 1;
                          return IconButton(
                            onPressed: () => setModalState(() => selected = starIndex),
                            icon: Icon(
                              starIndex <= selected ? Icons.star : Icons.star_border,
                              color: const Color(0xFF2E2E2E),
                              size: 36,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share more about your visit (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          try {
                            await fs.submitConsumerReview(
                              appointmentId: appointmentId,
                              consumerUid: consumerUid,
                              rating: selected,
                              comment: commentCtrl.text.trim().isEmpty
                                  ? null
                                  : commentCtrl.text.trim(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Thanks for your feedback')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E2E2E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Submit feedback'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    commentCtrl.dispose();
  }
}

Future<void> _addBookingToGoogleCalendar(
  BuildContext context,
  WidgetRef ref,
  Appointment appointment,
) async {
  final cal = ref.read(googleCalendarServiceProvider);
  try {
    await cal.insertBookingEvent(
      summary: appointment.serviceName,
      slotLabel: appointment.slotLabel,
      description: 'Campus Connect booking',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to Google Calendar')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to calendar: $e')),
      );
    }
  }
}

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
        final calConnected = (userSnap.data?.calendarGoogleEmail ?? '').isNotEmpty;
        return StreamBuilder(
          stream: fs.streamAppointmentsByConsumer(appUser!.uid),
          builder: (context, consumerSnap) {
            final consumerList = consumerSnap.data ?? [];
            final upcomingConsumer =
                consumerList.where((a) => _isUpcoming(a.status)).toList();
            final consumerPending = upcomingConsumer
                .where((a) => a.status == 'requested' || a.status == 'pending')
                .toList();
            final consumerScheduled = upcomingConsumer
                .where((a) => a.status == 'confirmed')
                .toList();

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
                      ...pending.map((a) => _SPBookingCard(
                            appointment: a,
                            fs: fs,
                            isPending: true,
                            onAddToGoogleCalendar: calConnected
                                ? () => _addBookingToGoogleCalendar(context, ref, a)
                                : null,
                          )),
                      ...confirmed.map((a) => _SPBookingCard(
                            appointment: a,
                            fs: fs,
                            isPending: false,
                            onAddToGoogleCalendar: calConnected
                                ? () => _addBookingToGoogleCalendar(context, ref, a)
                                : null,
                          )),
                      ...upcomingConsumer.map((a) => _ConsumerBookingCard(
                            appointmentId: a.appointmentId,
                            serviceName: a.serviceName,
                            dateTimeLabel: a.slotLabel,
                            price: a.price,
                            status: a.status,
                            consumerUid: a.consumerUid,
                            providerProfileId: a.providerProfileId,
                            reviewRating: a.reviewRating,
                            fs: fs,
                            onAddToGoogleCalendar: calConnected
                                ? () => _addBookingToGoogleCalendar(context, ref, a)
                                : null,
                          )),
                    ],
                  );
                },
              );
            }

            final filter = ref.watch(customerBookingFilterProvider);
            late final List<Appointment> filtered;
            switch (filter) {
              case _CustomerBookingFilter.pending:
                filtered = consumerPending;
                break;
              case _CustomerBookingFilter.scheduled:
                filtered = consumerScheduled;
                break;
              case _CustomerBookingFilter.all:
                filtered = upcomingConsumer;
                break;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CustomerFilterChips(
                  pendingCount: consumerPending.length,
                  scheduledCount: consumerScheduled.length,
                  filter: filter,
                  onChanged: (v) =>
                      ref.read(customerBookingFilterProvider.notifier).state = v,
                ),
                const SizedBox(height: 12),
                ...filtered
                  .map((a) => _ConsumerBookingCard(
                        appointmentId: a.appointmentId,
                        serviceName: a.serviceName,
                        dateTimeLabel: a.slotLabel,
                        price: a.price,
                        status: a.status,
                        consumerUid: a.consumerUid,
                        providerProfileId: a.providerProfileId,
                        reviewRating: a.reviewRating,
                        fs: fs,
                        onAddToGoogleCalendar: calConnected
                            ? () => _addBookingToGoogleCalendar(context, ref, a)
                            : null,
                      ))
                  ,
              ],
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
        _chip('Pending ($pendingCount)', true),
        const SizedBox(width: 8),
        _chip('Scheduled ($scheduledCount)', true),
      ],
    );
  }

  Widget _chip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.grey[200],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCECECE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _CustomerFilterChips extends StatelessWidget {
  const _CustomerFilterChips({
    required this.pendingCount,
    required this.scheduledCount,
    required this.filter,
    required this.onChanged,
  });

  final int pendingCount;
  final int scheduledCount;
  final _CustomerBookingFilter filter;
  final ValueChanged<_CustomerBookingFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(
          'Scheduled ($scheduledCount)',
          filter == _CustomerBookingFilter.scheduled,
          onTap: () => onChanged(
            filter == _CustomerBookingFilter.scheduled
                ? _CustomerBookingFilter.all
                : _CustomerBookingFilter.scheduled,
          ),
        ),
        const SizedBox(width: 8),
        _chip(
          'Pending ($pendingCount)',
          filter == _CustomerBookingFilter.pending,
          onTap: () => onChanged(
            filter == _CustomerBookingFilter.pending
                ? _CustomerBookingFilter.all
                : _CustomerBookingFilter.pending,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool active, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF2F2F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF8E949C)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

/// Consumer card: provider business name (regular weight), not a bold placeholder.
class _ProviderNameLine extends StatelessWidget {
  const _ProviderNameLine({
    this.fs,
    this.providerProfileId,
  });

  final FirestoreService? fs;
  final String? providerProfileId;

  @override
  Widget build(BuildContext context) {
    final id = providerProfileId;
    if (fs == null || id == null || id.isEmpty) {
      return const Text('Provider', style: _kPersonNameStyle);
    }
    return StreamBuilder<ProviderProfile?>(
      stream: fs!.streamProviderProfile(id),
      builder: (context, snap) {
        final name = snap.data?.businessName ?? 'Provider';
        return Text(
          name,
          style: _kPersonNameStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// ── SP Booking Card (Provider view) ─────────────────────────────────────

class _SPBookingCard extends StatefulWidget {
  const _SPBookingCard({
    required this.appointment,
    required this.fs,
    required this.isPending,
    this.onAddToGoogleCalendar,
  });

  final Appointment appointment;
  final FirestoreService fs;
  final bool isPending;
  final Future<void> Function()? onAddToGoogleCalendar;

  @override
  State<_SPBookingCard> createState() => _SPBookingCardState();
}

class _SPBookingCardState extends State<_SPBookingCard> {
  bool _notesExpanded = false;

  Future<void> _showAttendanceSheet(BuildContext context, Appointment a) async {
    final fs = widget.fs;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              title: const Text('Attended'),
              onTap: () => Navigator.pop(ctx, 'completed'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFF8C6D00)),
              title: const Text('No Show'),
              onTap: () => Navigator.pop(ctx, 'no_show'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF9C5D00)),
              title: const Text('Late Cancel (<24h)'),
              onTap: () => Navigator.pop(ctx, 'late_cancel'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFFA32121)),
              title: const Text('Cancelled'),
              subtitle: const Text('Shown in completed for 5 days'),
              onTap: () => Navigator.pop(ctx, 'cancelled'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      await fs.updateAppointmentStatus(a.appointmentId, selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _showProviderActionsDialog(
    BuildContext context,
    BuildContext anchorContext,
    Appointment a,
  ) async {
    final button = anchorContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final picked = await showMenu<String>(
      context: context,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1A1A1A), width: 1),
      ),
      position: rect,
      items: [
        if (widget.isPending)
          const PopupMenuItem<String>(
            value: 'edit',
            height: 44,
            child: Text('Edit Appointment'),
          ),
        if (widget.isPending) const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'calendar',
          height: 44,
          child: Text('Add to Calendar'),
        ),
        const PopupMenuItem<String>(
          value: 'cancel',
          height: 44,
          child: Text('Cancel'),
        ),
      ],
    );
    if (picked == null) return;

    final fs = widget.fs;
    if (picked == 'cancel') {
      try {
        await fs.updateAppointmentStatus(a.appointmentId, 'cancelled');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
      return;
    }

    if (picked == 'calendar') {
      final add = widget.onAddToGoogleCalendar;
      if (add != null) {
        await add();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect Google Calendar in profile to use this'),
          ),
        );
      }
      return;
    }

    if (!widget.isPending) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only pending appointments can be edited')),
        );
      }
      return;
    }
    final route = Uri(
      path: '/booking/edit',
      queryParameters: {
        'appointmentId': a.appointmentId,
        'providerId': a.providerProfileId,
        if ((a.serviceId ?? '').isNotEmpty) 'serviceId': a.serviceId!,
        'serviceName': a.serviceName,
        'slotLabel': a.slotLabel,
        if ((a.price ?? '').isNotEmpty) 'price': a.price!,
      },
    ).toString();
    if (context.mounted) {
      await context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final fs = widget.fs;
    final statusStyle = _statusStyle(a.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  a.serviceName,
                  style: _kAppointmentTitleStyle,
                ),
              ),
              if (widget.isPending) ...[
                _StatusPill(style: statusStyle),
                const SizedBox(width: 4),
              ],
              Builder(
                builder: (buttonCtx) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onPressed: () => _showProviderActionsDialog(context, buttonCtx, a),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.slotLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD8D8D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Appointment Notes', style: _kNotesRowLabelStyle),
                  ),
                  Icon(_notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          if (_notesExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                a.price?.isNotEmpty == true ? 'Total: ${a.price}' : 'No notes were provided.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                ),
              ),
            ),
          const SizedBox(height: 8),
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
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shortName,
                      style: _kPersonNameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openChat(context, a, fs),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E2E2E),
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 14),
                    label: const Text(
                      'Chat',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          if (widget.isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await fs.updateAppointmentStatus(a.appointmentId, 'confirmed');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appointment accepted')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E9E50),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 16),
                        SizedBox(width: 6),
                        Text('Accept'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await fs.updateAppointmentStatus(a.appointmentId, 'cancelled');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request declined')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA32121),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Decline'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAttendanceSheet(context, a),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2E2E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Log Attendance'),
              ),
            ),
        ],
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
    this.appointmentId,
    required this.serviceName,
    required this.dateTimeLabel,
    this.price,
    this.status,
    this.consumerUid,
    this.providerProfileId,
    this.reviewRating,
    this.fs,
    this.onAddToGoogleCalendar,
  });

  final String? appointmentId;
  final String serviceName;
  final String dateTimeLabel;
  final String? price;
  final String? status;
  final String? consumerUid;
  final String? providerProfileId;
  final int? reviewRating;
  final FirestoreService? fs;
  final Future<void> Function()? onAddToGoogleCalendar;

  @override
  State<_ConsumerBookingCard> createState() => _ConsumerBookingCardState();
}

class _ConsumerBookingCardState extends State<_ConsumerBookingCard> {
  bool _notesExpanded = false;

  Future<void> _openEditAppointmentScreen(BuildContext context) async {
    final appointmentId = widget.appointmentId;
    final providerProfileId = widget.providerProfileId;
    final status = widget.status ?? '';
    final isPending = status == 'requested' || status == 'pending';
    if (!isPending) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only pending appointments can be edited')),
        );
      }
      return;
    }
    if (appointmentId == null ||
        appointmentId.isEmpty ||
        providerProfileId == null ||
        providerProfileId.isEmpty) {
      return;
    }
    final route = Uri(
      path: '/booking/edit',
      queryParameters: {
        'appointmentId': appointmentId,
        'providerId': providerProfileId,
        'serviceName': widget.serviceName,
        'slotLabel': widget.dateTimeLabel,
        if ((widget.price ?? '').isNotEmpty) 'price': widget.price!,
      },
    ).toString();
    await context.push(route);
  }

  Future<void> _showCustomerActionsDialog(
    BuildContext context,
    BuildContext anchorContext,
  ) async {
    final button = anchorContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final picked = await showMenu<String>(
      context: context,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1A1A1A), width: 1),
      ),
      position: rect,
      items: const [
        PopupMenuItem<String>(
          value: 'edit',
          height: 44,
          child: Text('Edit Appointment'),
        ),
        PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'cancel',
          height: 44,
          child: Text('Cancel'),
        ),
      ],
    );
    if (!context.mounted) return;
    if (picked == 'edit') {
      await _openEditAppointmentScreen(context);
      return;
    }
    if (picked == 'cancel') {
      final fs = widget.fs;
      final appointmentId = widget.appointmentId;
      if (fs == null || appointmentId == null || appointmentId.isEmpty) return;
      try {
        await fs.updateAppointmentStatus(appointmentId, 'cancelled');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not cancel: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(widget.status);
    final slot = _parseSlotParts(widget.dateTimeLabel);
    final isPending =
        widget.status == 'requested' || widget.status == 'pending';
    final isScheduled = widget.status == 'confirmed';
    final showFeedback = widget.status == 'completed';
    final canOpenFeedback = showFeedback &&
        widget.appointmentId != null &&
        widget.appointmentId!.isNotEmpty &&
        widget.consumerUid != null &&
        widget.consumerUid!.isNotEmpty &&
        widget.fs != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.serviceName,
                  style: _kAppointmentTitleStyle,
                ),
              ),
              if (!isScheduled && widget.status != null) ...[
                _StatusPill(style: statusStyle),
                const SizedBox(width: 4),
              ],
              if (isPending)
                Builder(
                  builder: (buttonCtx) => IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: () => _showCustomerActionsDialog(context, buttonCtx),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                slot.dateLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[800],
                ),
              ),
              if (slot.timeLabel.isNotEmpty) ...[
                const SizedBox(width: 14),
                Icon(Icons.access_time, size: 14, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slot.timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD8D8D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Appointment Notes', style: _kNotesRowLabelStyle),
                  ),
                  Icon(_notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          if (_notesExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.price != null && widget.price!.isNotEmpty
                    ? 'Total: ${widget.price}'
                    : 'No notes were provided.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProviderNameLine(
                  fs: widget.fs,
                  providerProfileId: widget.providerProfileId,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openChat(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2E2E),
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                label: const Text(
                  'Chat',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          if (showFeedback && canOpenFeedback) ...[
            const SizedBox(height: 10),
            if (widget.reviewRating != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD8D8D8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'You rated this ${widget.reviewRating}/5',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showLeaveFeedbackSheet(
                    context,
                    fs: widget.fs!,
                    appointmentId: widget.appointmentId!,
                    consumerUid: widget.consumerUid!,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.star, size: 18),
                  label: const Text(
                    'Leave feedback',
                    style: TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
                  ),
                ),
              ),
          ],
          if (!showFeedback && widget.onAddToGoogleCalendar != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async => widget.onAddToGoogleCalendar!(),
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: const Text('Add to Calendar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ],
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

class _SlotParts {
  const _SlotParts(this.dateLabel, this.timeLabel);
  final String dateLabel;
  final String timeLabel;
}

_SlotParts _parseSlotParts(String raw) {
  final text = raw.trim();
  final m = RegExp(r'^(.*)\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])$').firstMatch(text);
  if (m == null) return _SlotParts(text, '');
  return _SlotParts((m.group(1) ?? '').trim(), (m.group(2) ?? '').trim());
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});
  final _StatusPillStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.fg),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completed Tab ───────────────────────────────────────────────────────

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab(
      {required this.appUser,
      required this.viewingAsProvider,
      required this.isDemo,
      required this.demoAppointments});

  final AppUser? appUser;
  final bool viewingAsProvider;
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
      stream: fs.streamUserProfile(appUser!.uid),
      builder: (context, userSnap) {
        final activeId = userSnap.data?.activeProviderProfileId;
        final calConnected = (userSnap.data?.calendarGoogleEmail ?? '').isNotEmpty;

        if (viewingAsProvider && activeId != null && activeId.isNotEmpty) {
          return StreamBuilder(
            stream: fs.streamAppointmentsByProviderProfile(activeId),
            builder: (context, snap) {
              final list = snap.data ?? [];
              final completed = list.where(_isProviderCompletedOutcome).toList();
              if (completed.isEmpty) return _emptyState(context);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: completed
                    .map((a) => _SPBookingCard(
                          appointment: a,
                          fs: fs,
                          isPending: false,
                          onAddToGoogleCalendar: calConnected
                              ? () => _addBookingToGoogleCalendar(context, ref, a)
                              : null,
                        ))
                    .toList(),
              );
            },
          );
        }

        return StreamBuilder(
          stream: fs.streamAppointmentsByConsumer(appUser!.uid),
          builder: (context, snap) {
            final list = snap.data ?? [];
            final completed = list.where((a) => a.status == 'completed').toList()
              ..sort((a, b) {
                final da = a.updatedAt ?? a.createdAt ?? DateTime(1970);
                final db = b.updatedAt ?? b.createdAt ?? DateTime(1970);
                return db.compareTo(da);
              });
            if (completed.isEmpty) return _emptyState(context);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: completed
                  .map((a) => _ConsumerBookingCard(
                        appointmentId: a.appointmentId,
                        serviceName: a.serviceName,
                        dateTimeLabel: a.slotLabel,
                        price: a.price,
                        status: a.status,
                        consumerUid: a.consumerUid,
                        providerProfileId: a.providerProfileId,
                        reviewRating: a.reviewRating,
                        fs: fs,
                        onAddToGoogleCalendar: calConnected
                            ? () => _addBookingToGoogleCalendar(context, ref, a)
                            : null,
                      ))
                  .toList(),
            );
          },
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
            const Text(
              'No previous bookings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
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
