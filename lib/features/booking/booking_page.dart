import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.providerId});

  final String providerId;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _step = 0;
  String _selectedSlot = 'Jun 10, 2024 9:41 AM';

  @override
  Widget build(BuildContext context) {
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
      body: _step == 0 ? _buildTimeStep(context) : _buildReviewStep(context),
    );
  }

  Widget _buildTimeStep(BuildContext context) {
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
              Text('Provider ${widget.providerId}\'s Availability', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            child: Text(_selectedSlot),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('More time slots')),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Continue'),
          ),
        ],
      ),
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
              Text('Provider ${widget.providerId}', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 24),
          const ListTile(title: Text('Service'), subtitle: Text('Service name')),
          const ListTile(title: Text('Date & time'), subtitle: Text('Jun 10, 2024 9:41 AM')),
          const ListTile(title: Text('Location'), subtitle: Text('TBD')),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text(r'$25', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking confirmed')));
              context.go('/appointments');
            },
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }
}
