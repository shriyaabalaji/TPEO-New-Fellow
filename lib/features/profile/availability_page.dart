import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/availability_slot.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class AvailabilityPage extends ConsumerWidget {
  const AvailabilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Availability'),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(child: Text('Sign in to set your availability.'));
          }
          if (fs == null) {
            return const Center(child: Text('Firebase not configured.'));
          }
          return StreamBuilder(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final activeId = userSnap.data?.activeProviderProfileId;
              if (activeId == null || activeId.isEmpty) {
                return const Center(child: Text('Create a provider profile first.'));
              }
              return StreamBuilder<List<AvailabilitySlot>>(
                stream: fs.streamAvailability(activeId),
                builder: (context, snap) {
                  final slots = snap.data ?? [];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Recurring weekly slots',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...slots.map((s) => _SlotCard(
                              slot: s,
                              onRemove: () async {
                                final updated = slots.where((x) => x != s).toList();
                                await fs.setAvailability(activeId, updated);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot removed')));
                                }
                              },
                            )),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showAddSlotDialog(context, ref, activeId, slots, fs),
                          icon: const Icon(Icons.add),
                          label: const Text('Add time slot'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context, WidgetRef ref, String providerId, List<AvailabilitySlot> current, dynamic fs) {
    int day = 1;
    final startCtrl = TextEditingController(text: '14:00');
    final endCtrl = TextEditingController(text: '18:00');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add time slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(_dayLabels[i]))),
                onChanged: (v) => setState(() => day = v ?? 1),
              ),
              const SizedBox(height: 12),
              TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start (e.g. 14:00)')),
              const SizedBox(height: 12),
              TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End (e.g. 18:00)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final start = startCtrl.text.trim();
                final end = endCtrl.text.trim();
                if (start.isEmpty || end.isEmpty) return;
                Navigator.pop(ctx);
                final updated = [...current, AvailabilitySlot(dayOfWeek: day, start: start, end: end)];
                await fs.setAvailability(providerId, updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot added')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onRemove});

  final AvailabilitySlot slot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dayLabel = slot.dayOfWeek >= 1 && slot.dayOfWeek <= 7 ? _dayLabels[slot.dayOfWeek - 1] : 'Day ${slot.dayOfWeek}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$dayLabel ${slot.start} - ${slot.end}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
