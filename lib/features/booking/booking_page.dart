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
            final displayMonth = '${_monthNames[selectedWeekStart.month - 1]} ${selectedWeekStart.year}';
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
            final byDateLabel = <String, List<TimeOption>>{};
            for (final o in optionsForWeek) {
              final key = o.dateLabel ?? o.dayName;
              byDateLabel.putIfAbsent(key, () => []).add(o);
            }
            final dateOrder = byDateLabel.keys.toList()..sort((a, b) {
              final oa = byDateLabel[a]!.first;
              final ob = byDateLabel[b]!.first;
              final da = oa.date ?? DateTime.now();
              final db = ob.date ?? DateTime.now();
              return da.compareTo(db);
            });
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
                  Text(
                    displayMonth,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: isSelectedWeek ? FontWeight.w600 : FontWeight.normal,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: isSelectedWeek ? 1.0 : 0.7),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dayLetters[i],
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontWeight: isSelectedWeek ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: dateOrder.isEmpty
                        ? Center(
                            child: Text(
                              'No times this week. Scroll to another week.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: dateOrder.length,
                            itemBuilder: (context, i) {
                              final dateLabel = dateOrder[i];
                              final dayOptions = byDateLabel[dateLabel]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                                    child: Text(
                                      dateLabel,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: dayOptions.map((o) {
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
                                    }).toList(),
                                  ),
                                ],
                              );
                            },
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
