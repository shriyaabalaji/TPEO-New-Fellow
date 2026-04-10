import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/calendar/calendar_providers.dart';
import '../../models/availability_slot.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../utils/availability_options.dart';
import '../auth/effective_user_provider.dart';
import '../onboarding/onboarding_progress.dart';
import '../profile/provider_account_controller.dart';

enum _CalDayKind { previousMonth, currentMonth, nextMonth }

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({
    super.key,
    required this.providerId,
    this.initialServiceId,
    this.initialServiceName,
    this.initialPrice,
    this.editAppointmentId,
    this.initialSlotLabel,
    this.initialNotes,
  });

  final String providerId;
  final String? initialServiceId;
  final String? initialServiceName;
  final String? initialPrice;
  final String? editAppointmentId;
  final String? initialSlotLabel;
  final String? initialNotes;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _step = 0;
  String? _selectedServiceId;
  String _selectedSlotLabel = '';
  String _selectedServiceName = '';
  String _selectedPrice = r'$25';
  final TextEditingController _bookingNotesController = TextEditingController();
  DateTime? _selectedDate;
  /// First day of the month shown in the calendar grid.
  late DateTime _calendarMonth;

  static const _weekdayHeaders = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  bool get _isEditMode =>
      widget.editAppointmentId != null && widget.editAppointmentId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
    if (widget.initialServiceId != null &&
        widget.initialServiceName != null &&
        widget.initialPrice != null) {
      _selectedServiceId = widget.initialServiceId;
      _selectedServiceName = widget.initialServiceName!;
      _selectedPrice = widget.initialPrice!;
      _step = 0;
    }
    if (widget.initialSlotLabel != null && widget.initialSlotLabel!.isNotEmpty) {
      _selectedSlotLabel = widget.initialSlotLabel!;
    }
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _bookingNotesController.text = widget.initialNotes!;
    }
  }

  @override
  void dispose() {
    _bookingNotesController.dispose();
    super.dispose();
  }

  /// Column index 0 = Sunday … 6 = Saturday (matches `_weekdayHeaders`).
  static int _weekdaySundayFirst(DateTime d) {
    final w = d.weekday;
    return w % 7;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _shiftCalendarMonth(int deltaMonths) {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + deltaMonths, 1);
    });
  }

  void _onCalendarDayTapped(
    BuildContext context,
    List<TimeOption> optionsAll,
    DateTime normalized,
  ) {
    setState(() {
      if (normalized.month != _calendarMonth.month || normalized.year != _calendarMonth.year) {
        _calendarMonth = DateTime(normalized.year, normalized.month, 1);
      }
      _selectedDate = normalized;
      _selectedSlotLabel = '';
    });
    final slots = <TimeOption>[];
    for (final o in optionsAll) {
      final d = o.date;
      if (d != null && _isSameCalendarDay(d, normalized)) {
        slots.add(o);
      }
    }
    _showAvailableTimesSheet(context, normalized, slots);
  }

  Future<void> _showAvailableTimesSheet(
    BuildContext context,
    DateTime date,
    List<TimeOption> slots,
  ) async {
    final dateStr = '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
    String tempSelectedSlot = _selectedSlotLabel;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'All Available Times',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    if (slots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No available slots for this date.',
                          textAlign: TextAlign.center,
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: slots.map((o) {
                          final isSelected = tempSelectedSlot == o.slotLabel;
                          return InkWell(
                            onTap: () {
                              setSheetState(() => tempSelectedSlot = o.slotLabel);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF35393F)
                                    : Colors.white,
                                border: Border.all(color: const Color(0xFF1F1F1F)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                o.timeLabel,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 22),
                    _buildPrimaryButton(
                      ctx,
                      label: 'Continue',
                      onPressed: tempSelectedSlot.isEmpty
                          ? () {}
                          : () {
                              setState(() {
                                _selectedSlotLabel = tempSelectedSlot;
                                _step = 1;
                              });
                              Navigator.of(ctx).pop();
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const _totalSteps = 3;

  void _onBookingBack() {
    if (_step == 3) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/appointments');
      }
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/find');
    }
  }

  String _bookingStepScreenTitle() {
    switch (_step) {
      case 0:
        return _isEditMode ? 'Update Time Slot' : 'Choose a Time Slot';
      case 1:
        return 'Booking Notes';
      case 2:
        return _isEditMode ? 'Review and Save Session' : 'Review and Confirm Session';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BookingTopBar(
                title: _step == 3
                    ? 'Appointments'
                    : (_isEditMode ? 'Edit Session' : 'Book Session'),
                onBack: _onBookingBack,
              ),
              const SizedBox(height: 24),
              if (_step < 3) ...[
                OnboardingStepHeader(
                  currentStep: _step,
                  totalSteps: _totalSteps,
                ),
                const SizedBox(height: 16),
                Text(
                  _bookingStepScreenTitle(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                ),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: fs == null
                    ? _buildNoFirebaseFallback(context)
                    : _step == 0
                        ? _buildTimeStep(context, fs)
                        : _step == 1
                            ? _buildNotesStep(context, fs)
                            : _step == 2
                                ? _buildReviewStep(context)
                                : _buildSuccessStep(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoFirebaseFallback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Text('Firebase not configured. Sign in to book.')),
        const Spacer(),
        _buildPrimaryButton(
          context,
          label: 'Continue with demo',
          onPressed: () {
            setState(() {
              _selectedSlotLabel = 'Jun 10, 2024 2:00 PM';
              _step = 1;
            });
          },
        ),
      ],
    );
  }

  static const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  Widget _buildTimeStep(BuildContext context, dynamic fs) {
    final profileStream = fs.streamProviderProfile(widget.providerId);
    final availabilityStream = fs.streamAvailability(widget.providerId);

    return StreamBuilder<ProviderProfile?>(
      stream: profileStream,
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final providerName = profile?.businessName ?? 'Provider ${widget.providerId}';
        return StreamBuilder<List<Service>>(
          stream: fs.streamServices(widget.providerId),
          builder: (context, serviceSnap) {
            final services = serviceSnap.data ?? <Service>[];
            final selectedService = services
                .where((s) => s.serviceId == _selectedServiceId)
                .cast<Service?>()
                .firstWhere((s) => s != null, orElse: () => services.isNotEmpty ? services.first : null);
            final shouldAutoSyncService = selectedService != null &&
                ((_selectedServiceId != null &&
                        _selectedServiceId != selectedService.serviceId) ||
                    _selectedServiceName.isEmpty ||
                    _selectedPrice.isEmpty);
            if (shouldAutoSyncService) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedServiceId = selectedService.serviceId;
                  _selectedServiceName = selectedService.name;
                  _selectedPrice = selectedService.price;
                });
              });
            }
            return StreamBuilder<List<AvailabilitySlot>>(
              stream: availabilityStream,
              builder: (context, availSnap) {
            final slots = availSnap.data ?? [];
            final monthAnchor = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
            final optionsAll = expandSlotsToTimeOptionsWithDates(slots, monthAnchor, 10);
            if (optionsAll.isEmpty && expandSlotsToTimeOptions(slots).isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$providerName\'s Availability', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 16),
                  const Center(child: Text('No availability set. Check back later.')),
                  const Spacer(),
                  _buildPrimaryButton(
                    context,
                    label: 'Continue',
                    onPressed: () {
                      setState(() {
                        _selectedSlotLabel = 'TBD';
                        _step = 1;
                      });
                    },
                  ),
                ],
              );
            }
            final effectiveSelectedDate = _selectedDate;

            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD0D0D0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '5.0 (37)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                              Text(
                                _selectedPrice,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.bolt, size: 14),
                        const SizedBox(width: 4),
                        const Text('Active Today', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD0D0D0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildMonthYearSelectors(context),
                        const SizedBox(height: 8),
                        _buildMonthCalendarGrid(
                          context,
                          optionsAll: optionsAll,
                          selectedDate: effectiveSelectedDate,
                          onDayTapped: (d) => _onCalendarDayTapped(context, optionsAll, d),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tap a date on the calendar to see available times.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                  if (_selectedSlotLabel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPrimaryButton(
                      context,
                      label: 'Continue',
                      onPressed: () => setState(() => _step = 1),
                    ),
                  ],
                ],
            );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMonthYearSelectors(BuildContext context) {
    final now = DateTime.now();
    final minY = now.year - 2;
    final maxY = now.year + 3;
    final years = List.generate(maxY - minY + 1, (i) => minY + i);
    final safeYear = _calendarMonth.year.clamp(minY, maxY);

    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 26),
          onPressed: () => _shiftCalendarMonth(-1),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: _calendarMonth.month,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                items: List.generate(
                  12,
                  (i) {
                    final m = i + 1;
                    return DropdownMenuItem<int>(
                      value: m,
                      child: Text(_monthNames[m - 1].substring(0, 3)),
                    );
                  },
                ),
                onChanged: (m) {
                  if (m == null) return;
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, m, 1);
                  });
                },
              ),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: safeYear,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                items: years
                    .map(
                      (y) => DropdownMenuItem<int>(
                        value: y,
                        child: Text('$y'),
                      ),
                    )
                    .toList(),
                onChanged: (y) {
                  if (y == null) return;
                  setState(() {
                    _calendarMonth = DateTime(y, _calendarMonth.month, 1);
                  });
                },
              ),
            ],
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.chevron_right, color: Colors.black, size: 26),
          onPressed: () => _shiftCalendarMonth(1),
        ),
      ],
    );
  }

  Widget _buildMonthCalendarGrid(
    BuildContext context, {
    required List<TimeOption> optionsAll,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDayTapped,
  }) {
    final y = _calendarMonth.year;
    final m = _calendarMonth.month;
    final firstThis = DateTime(y, m, 1);
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final leading = _weekdaySundayFirst(firstThis);
    final cellsBefore = leading;
    final prevMonthEnd = DateTime(y, m, 0);
    final prevDays = prevMonthEnd.day;

    final totalMain = cellsBefore + daysInMonth;
    final rowCount = (totalMain / 7).ceil();

    bool dayHasSlots(DateTime date) {
      for (final o in optionsAll) {
        final d = o.date;
        if (d != null && _isSameCalendarDay(d, date)) return true;
      }
      return false;
    }

    Widget dayCell(int index) {
      late final DateTime date;
      late final _CalDayKind kind;

      if (index < cellsBefore) {
        final day = prevDays - (cellsBefore - 1 - index);
        date = DateTime(y, m - 1, day);
        kind = _CalDayKind.previousMonth;
      } else if (index < cellsBefore + daysInMonth) {
        final day = index - cellsBefore + 1;
        date = DateTime(y, m, day);
        kind = _CalDayKind.currentMonth;
      } else {
        final day = index - cellsBefore - daysInMonth + 1;
        date = DateTime(y, m + 1, day);
        kind = _CalDayKind.nextMonth;
      }

      final normalized = DateTime(date.year, date.month, date.day);
      final isSelected = selectedDate != null && _isSameCalendarDay(normalized, selectedDate);
      final hasSlots = dayHasSlots(normalized);

      final Color numberColor;
      if (isSelected) {
        numberColor = Colors.white;
      } else if (kind == _CalDayKind.nextMonth) {
        numberColor = const Color(0xFFC62828);
      } else if (kind == _CalDayKind.previousMonth) {
        numberColor = Colors.black38;
      } else {
        numberColor = Colors.black87;
      }

      final Color circleFill;
      if (isSelected) {
        circleFill = Colors.black;
      } else if (hasSlots) {
        circleFill = Colors.black12;
      } else {
        circleFill = Colors.grey.shade200;
      }

      return Expanded(
        child: InkWell(
          onTap: () => onDayTapped(normalized),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleFill,
                ),
                child: Text(
                  '${normalized.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: numberColor,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: _weekdayHeaders
              .map(
                (h) => Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < rowCount; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (c) => dayCell(r * 7 + c)),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesStep(BuildContext context, dynamic fs) {
    return StreamBuilder<ProviderProfile?>(
      stream: fs.streamProviderProfile(widget.providerId),
      builder: (context, snap) {
        final providerName = snap.data?.businessName ?? 'Provider ${widget.providerId}';
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Help your provider prepare by sharing what you are looking for and any specific details.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bookingNotesController,
                minLines: 5,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: 'Type here',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                providerName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 12),
              _buildPrimaryButton(
                context,
                label: 'Continue',
                onPressed: () => setState(() => _step = 2),
              ),
            ],
        );
      },
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);
    return StreamBuilder<ProviderProfile?>(
      stream: fs?.streamProviderProfile(widget.providerId),
      builder: (context, snap) {
        final providerName = snap.data?.businessName ?? 'Provider ${widget.providerId}';
        final providerPhoto = snap.data?.bannerUrl;
        final split = _splitSlotLabel(_selectedSlotLabel);
        final notesText = _bookingNotesController.text.trim().isNotEmpty
            ? _bookingNotesController.text.trim()
            : 'No notes added.';
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service',
                style: const TextStyle(fontSize: 40 / 1.6, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.push('/provider/${widget.providerId}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1F1F1F)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            providerPhoto != null && providerPhoto.isNotEmpty
                                ? NetworkImage(providerPhoto)
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(providerName,
                                style: const TextStyle(
                                    fontSize: 31 / 2.0,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.star, size: 18),
                                SizedBox(width: 6),
                                Text('5.0 (37)',
                                    style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Icon(Icons.bolt, size: 18),
                                SizedBox(width: 6),
                                Text('Active Today',
                                    style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5C5C5C),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 21, color: Color(0xFF4A4A4A)),
                  const SizedBox(width: 10),
                  Text(split.dateLabel,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 21, color: Color(0xFF4A4A4A)),
                  const SizedBox(width: 10),
                  Text(split.timeLabel,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Booking Notes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5C5C5C),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                constraints: const BoxConstraints(minHeight: 96),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1F1F1F)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notesText,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF2B2B2B)),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildPrimaryButton(
                  context,
                  label: _isEditMode ? 'Save Changes' : 'Confirm Booking',
                  onPressed: () async {
                  final firestore = ref.read(firestoreServiceProvider);
                  if (_isEditMode) {
                    final appointmentId = widget.editAppointmentId!;
                    if (firestore == null) return;
                    try {
                      await firestore.updateAppointment(
                        appointmentId: appointmentId,
                        serviceName: _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service',
                        slotLabel: _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD',
                        price: _selectedPrice,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Booking failed: $e')),
                      );
                      return;
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Appointment updated')),
                    );
                    this.context.go('/appointments');
                    return;
                  }
                  final appUser = await ref.read(effectiveUserProvider.future);
                  if (appUser != null && !appUser.isDemo && firestore != null) {
                    try {
                      await firestore.createAppointment(
                        consumerUid: appUser.uid,
                        providerProfileId: widget.providerId,
                        serviceId: _selectedServiceId,
                        serviceName: _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service',
                        slotLabel: _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD',
                        price: _selectedPrice,
                        notes: _bookingNotesController.text.trim().isEmpty
                            ? null
                            : _bookingNotesController.text.trim(),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Booking failed: $e')),
                      );
                      return;
                    }
                  }
                  if (appUser != null && appUser.isDemo) {
                    final title =
                        _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Booking';
                    final subtitle =
                        _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD';
                    await ref.read(demoAppointmentsProvider.notifier).add(
                          DemoAppointment(
                            id: 'd${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            subtitle: subtitle,
                          ),
                        );
                  }
                  if (mounted) {
                    setState(() => _step = 3);
                  }
                  },
                ),
              ),
            ],
        );
      },
    );
  }

  Widget _buildSuccessStep(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'Booking Request Sent!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your request will be reviewed by the provider shortly.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll receive a notification once they accept or decline. If approved, they will contact you directly to confirm the final details.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please note that you may cancel appointments up to 24h before. After 24h, late cancellations will appear on your profile, visible to service providers.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final cal = ref.read(googleCalendarServiceProvider);
                await cal.insertBookingEvent(
                  summary: _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Booking',
                  slotLabel: _selectedSlotLabel,
                  description: 'Booked via Bevo Booked',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to Google Calendar')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add to calendar: $e')),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Color(0xFF2B2B2B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF2B2B2B)),
            label: const Text('Add to Google Calendar', style: TextStyle(color: Color(0xFF2B2B2B))),
          ),
          const SizedBox(height: 12),
          _buildPrimaryButton(
            context,
            label: 'View Bookings',
            onPressed: () => context.go('/appointments'),
          ),
        ],
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  _SlotParts _splitSlotLabel(String raw) {
    if (raw.trim().isEmpty) return const _SlotParts('TBD', 'TBD');
    final trimmed = raw.trim();
    final separators = [' at ', ' · ', ', '];
    for (final sep in separators) {
      if (trimmed.contains(sep)) {
        final parts = trimmed.split(sep);
        if (parts.length >= 2) {
          return _SlotParts(parts.first.trim(), parts.sublist(1).join(sep).trim());
        }
      }
    }
    return _SlotParts(trimmed, 'TBD');
  }
}

class _BookingTopBar extends StatelessWidget {
  const _BookingTopBar({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BookingCircleBackButton(onPressed: onBack),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _BookingCircleBackButton extends StatelessWidget {
  const _BookingCircleBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
      ),
    );
  }
}

class _SlotParts {
  const _SlotParts(this.dateLabel, this.timeLabel);
  final String dateLabel;
  final String timeLabel;
}
