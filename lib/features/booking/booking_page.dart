import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/availability_slot.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _step = 0;
  String _selectedSlotLabel = '';
  String _selectedServiceName = '';
  String _selectedPrice = r'$25';

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Booking'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 2,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: fs == null
          ? _buildTimeStepFallback(context)
          : _step == 0
              ? _buildTimeStep(context, fs)
              : _buildReviewStep(context),
    );
  }

  Widget _buildTimeStepFallback(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text('Choose a Time Slot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('Provider ${widget.providerId}\'s Availability', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          const Center(child: Text('No availability data.')),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSlotLabel = 'Jun 10, 2024 2:00 PM';
                _step = 1;
              });
            },
            child: const Text('Continue with demo slot'),
          ),
        ],
      ),
    );
  }

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
            final slotLabels = slots.map((s) {
              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final d = s.dayOfWeek >= 1 && s.dayOfWeek <= 7 ? days[s.dayOfWeek - 1] : 'Day${s.dayOfWeek}';
              return '$d ${s.start}–${s.end}';
            }).toList();
            if (slotLabels.isEmpty) {
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
                          _selectedServiceName = 'Service';
                          _step = 1;
                        });
                      },
                      child: const Text('Continue anyway'),
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
                  Text('Choose a Time Slot', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const CircleAvatar(radius: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text('$providerName\'s Availability', style: Theme.of(context).textTheme.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...slotLabels.map((label) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedSlotLabel = label;
                              _selectedServiceName = 'Service';
                              _step = 1;
                            });
                          },
                          child: Text(label),
                        ),
                      )),
                  const Spacer(),
                  if (_selectedSlotLabel.isNotEmpty)
                    ElevatedButton(
                      onPressed: () => setState(() => _step = 1),
                      child: const Text('Continue'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewStep(BuildContext context) {
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
              Expanded(child: Text('Provider ${widget.providerId}', style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(title: const Text('Service'), subtitle: Text(_selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service name')),
          ListTile(title: const Text('Time'), subtitle: Text(_selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'Jun 10, 2024 9:41 AM')),
          const ListTile(title: Text('Location'), subtitle: Text('TBD')),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text(_selectedPrice, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                    serviceName: _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Service',
                    slotLabel: _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD',
                    price: _selectedPrice,
                  );
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
                  return;
                }
              }
              if (appUser != null && appUser.isDemo) {
                final title = _selectedServiceName.isNotEmpty ? _selectedServiceName : 'Booking';
                final subtitle = _selectedSlotLabel.isNotEmpty ? _selectedSlotLabel : 'TBD';
                await ref.read(demoAppointmentsProvider.notifier).add(DemoAppointment(
                  id: 'd${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  subtitle: subtitle,
                ));
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking confirmed')));
                context.go('/appointments');
              }
            },
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }
}
