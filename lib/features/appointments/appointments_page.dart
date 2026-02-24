import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _ScheduledTab(viewingAsProvider: viewingAsProvider),
          _CompletedTab(viewingAsProvider: viewingAsProvider),
        ],
      ),
    );
  }
}

class _ScheduledTab extends StatelessWidget {
  const _ScheduledTab({required this.viewingAsProvider});

  final bool viewingAsProvider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewingAsProvider) ...[
            Text('Pending requests', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _PendingRequestCard(expandable: true),
            _PendingRequestCard(expandable: true),
            const SizedBox(height: 24),
            Text('Confirmed as provider', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _AppointmentTile(title: 'Confirmed provider apt 1'),
            _AppointmentTile(title: 'Confirmed provider apt 2'),
            const SizedBox(height: 24),
          ],
          Text(viewingAsProvider ? 'Your appointments' : 'Pending', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!viewingAsProvider) _AppointmentTile(title: 'Pending appointment (non-editable)'),
          _AppointmentTile(title: 'Confirmed consumer apt 1'),
          _AppointmentTile(title: 'Confirmed consumer apt 2'),
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

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.event),
      title: Text(title),
      subtitle: const Text('Details'),
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab({required this.viewingAsProvider});

  final bool viewingAsProvider;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AppointmentTile(title: 'Past appointment 1'),
        _AppointmentTile(title: 'Past appointment 2'),
      ],
    );
  }
}
