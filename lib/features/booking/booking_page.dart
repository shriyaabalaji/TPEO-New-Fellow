import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/availability_slot.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../utils/availability_options.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({
    super.key,
    required this.providerId,
    this.initialServiceId,
    this.initialServiceName,
    this.initialPrice,
  });

  final String providerId;
  final String? initialServiceId;
  final String? initialServiceName;
  final String? initialPrice;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _step = 0;
  String? _selectedServiceId;
  String _selectedSlotLabel = '';
  String _selectedServiceName = '';
  String _selectedPrice = r'$25';
  int _selectedWeekIndex = 0;
  late PageController _bookingWeekPageController;
  DateTime? _selectedDate;

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _bookingWeekPageController = PageController(initialPage: 0);
    if (widget.initialServiceId != null &&
        widget.initialServiceName != null &&
        widget.initialPrice != null) {
      _selectedServiceId = widget.initialServiceId;
      _selectedServiceName = widget.initialServiceName!;
      _selectedPrice = widget.initialPrice!;
      _step = 1;
    }
  }

  @override
  void dispose() {
    _bookingWeekPageController.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> _bookingWeekStarts() {
    final now = DateTime.now();
    final start = _mondayOf(now);
    return List.generate(16, (i) => start.add(Duration(days: i * 7)));
  }

  static const _totalSteps = 3;

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
              if (_step > 0) {
                setState(() => _step--);
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/find');
              }
            },
        ),
        title: const Text('Booking'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: fs == null
          ? _buildNoFirebaseFallback(context)
          : _step == 0
              ? _buildServiceStep(context, fs)
              : _step == 1
                  ? _buildTimeStep(context, fs)
                  : _buildReviewStep(context),
    );
  }

  Widget _buildNoFirebaseFallback(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text('Choose a Service', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          const Center(child: Text('Firebase not configured. Sign in to book.')),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSlotLabel = 'Jun 10, 2024 2:00 PM';
                _step = 1;
              });
            },
            child: const Text('Continue with demo'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStep(BuildContext context, dynamic fs) {
    return StreamBuilder<List<Service>>(
      stream: fs.streamServices(widget.providerId),
      builder: (context, snap) {
        final services = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && services.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (services.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Choose a Service', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                const Center(
                  child: Text('This provider has no services listed yet. Check back later.'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Choose a Service', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              ...services.map((s) {
                final duration = s.durationMinutes >= 60
                    ? '${s.durationMinutes ~/ 60} hr'
                    : '${s.durationMinutes} min';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(s.name),
                      subtitle: Text('${s.price} · $duration'),
                      onTap: () {
                        setState(() {
                          _selectedServiceId = s.serviceId;
                          _selectedServiceName = s.name;
                          _selectedPrice = s.price;
                          _step = 1;
                        });
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
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
        return StreamBuilder<List<AvailabilitySlot>>(
          stream: availabilityStream,
          builder: (context, availSnap) {
            final slots = availSnap.data ?? [];
            final weekStarts = _bookingWeekStarts();
            if (weekStarts.isEmpty) {
              return const Center(child: Text('No weeks available.'));
            }
            final selectedWeekStart = _selectedWeekIndex < weekStarts.length
                ? weekStarts[_selectedWeekIndex]
                : weekStarts.first;

            // Build list of distinct months covered by available weeks for month dropdown.
            final months = <DateTime>[];
            for (final ws in weekStarts) {
              final m = DateTime(ws.year, ws.month, 1);
              if (months.isEmpty || !months.last.isAtSameMomentAs(m)) {
                months.add(m);
              }
            }
            final currentMonth = DateTime(selectedWeekStart.year, selectedWeekStart.month, 1);

            final optionsForWeek = expandSlotsToTimeOptionsWithDates(slots, selectedWeekStart, 1);
            if (optionsForWeek.isEmpty && expandSlotsToTimeOptions(slots).isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text('Choose a Time Slot', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    Text('$providerName\'s Availability', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 16),
                    const Center(child: Text('No availability set. Check back later.')),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedSlotLabel = 'TBD';
                          _step = 2;
                        });
                      },
                      child: const Text('Continue anyway'),
                    ),
                  ],
                ),
              );
            }
            // Determine which calendar date is currently selected.
            final effectiveSelectedDate = _selectedDate;

            // Time options for the selected date, if any.
            final optionsForSelectedDate = <TimeOption>[];
            if (effectiveSelectedDate != null) {
              for (final o in optionsForWeek) {
                final d = o.date;
                if (d == null) continue;
                if (d.year == effectiveSelectedDate.year &&
                    d.month == effectiveSelectedDate.month &&
                    d.day == effectiveSelectedDate.day) {
                  optionsForSelectedDate.add(o);
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text('Choose a Time Slot', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '$providerName\'s Availability',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<DateTime>(
                        value: currentMonth,
                        underline: const SizedBox(),
                        items: months
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text('${_monthNames[m.month - 1]} ${m.year}'),
                              ),
                            )
                            .toList(),
                        onChanged: (d) {
                          if (d == null) return;
                          final idx = weekStarts.indexWhere((ws) => ws.year == d.year && ws.month == d.month);
                          if (idx != -1) {
                            setState(() {
                              _selectedWeekIndex = idx;
                            });
                            if (_bookingWeekPageController.hasClients) {
                              _bookingWeekPageController.jumpToPage(idx);
                            }
                          }
                        },
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _selectedWeekIndex > 0
                                ? () {
                                    final newIndex = _selectedWeekIndex - 1;
                                    setState(() => _selectedWeekIndex = newIndex);
                                    if (_bookingWeekPageController.hasClients) {
                                      _bookingWeekPageController.animateToPage(
                                        newIndex,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _selectedWeekIndex < weekStarts.length - 1
                                ? () {
                                    final newIndex = _selectedWeekIndex + 1;
                                    setState(() => _selectedWeekIndex = newIndex);
                                    if (_bookingWeekPageController.hasClients) {
                                      _bookingWeekPageController.animateToPage(
                                        newIndex,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: PageView.builder(
                      controller: _bookingWeekPageController,
                      onPageChanged: (i) {
                        if (i >= 0 && i < weekStarts.length) {
                          setState(() => _selectedWeekIndex = i);
                        }
                      },
                      itemCount: weekStarts.length,
                      itemBuilder: (context, pageIndex) {
                        final weekStart = weekStarts[pageIndex];
                        final isSelectedWeek = pageIndex == _selectedWeekIndex;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (i) {
                            final date = weekStart.add(Duration(days: i == 0 ? -1 : i - 1));
                            final dayHasSlots = optionsForWeek.any((o) {
                              final d = o.date;
                              if (d == null) return false;
                              return d.year == date.year && d.month == date.month && d.day == date.day;
                            });
                            final isSelectedDate = effectiveSelectedDate != null &&
                                effectiveSelectedDate.year == date.year &&
                                effectiveSelectedDate.month == date.month &&
                                effectiveSelectedDate.day == date.day;
                            final circleColor = isSelectedDate
                                ? const Color(0xFFCC5500) // dark orange for selected date
                                : dayHasSlots
                                    ? const Color(0xFFFFE0B2) // light orange for dates with availability
                                    : Colors.grey.shade300; // gray for dates with no availability
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedWeekIndex = pageIndex;
                                    _selectedDate = DateTime(date.year, date.month, date.day);
                                    _selectedSlotLabel = '';
                                  });
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: circleColor,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${date.day}',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              fontWeight: isSelectedDate ? FontWeight.w700 : FontWeight.normal,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(
                                                    alpha: isSelectedWeek ? 1.0 : 0.7,
                                                  ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _dayLetters[i],
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: isSelectedDate ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: effectiveSelectedDate == null
                        ? Center(
                            child: Text(
                              'Select a date to see availability.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                            ),
                          )
                        : optionsForSelectedDate.isEmpty
                            ? Center(
                                child: Text(
                                  'No available slots for this date.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                ),
                              )
                            : ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                                    child: Text(
                                      '${_monthNames[effectiveSelectedDate.month - 1]} ${effectiveSelectedDate.day}, ${effectiveSelectedDate.year}',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: optionsForSelectedDate
                                        .map((o) {
                                          final isSelected = _selectedSlotLabel == o.slotLabel;
                                          return ChoiceChip(
                                            label: Text(o.timeLabel),
                                            selected: isSelected,
                                            onSelected: (_) {
                                              setState(() {
                                                _selectedSlotLabel = o.slotLabel;
                                              });
                                            },
                                          );
                                        })
                                        .toList(),
                                  ),
                                ],
                              ),
                  ),
                  if (_selectedSlotLabel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _step = 2),
                      child: const Text('Continue'),
                    ),
                  ],
                ],
              ),
            );
          },
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
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Review Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Row(
                children: [
                  const CircleAvatar(radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      providerName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Service'),
                subtitle: Text(_selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service'),
              ),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(_selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD'),
              ),
              const ListTile(title: Text('Location'), subtitle: Text('TBD')),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    _selectedPrice,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final appUser = await ref.read(effectiveUserProvider.future);
                  final firestore = ref.read(firestoreServiceProvider);
                  if (appUser != null && !appUser.isDemo && firestore != null) {
                    try {
                      await firestore.createAppointment(
                        consumerUid: appUser.uid,
                        providerProfileId: widget.providerId,
                        serviceId: _selectedServiceId,
                        serviceName: _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service',
                        slotLabel: _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD',
                        price: _selectedPrice,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Booking failed: $e')),
                        );
                      }
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking confirmed')),
                    );
                    context.go('/appointments');
                  }
                },
                child: const Text('Confirm Booking'),
              ),
            ],
          ),
        );
      },
    );
  }
}
