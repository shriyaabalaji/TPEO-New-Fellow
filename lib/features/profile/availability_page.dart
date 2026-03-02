import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/availability_slot.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// 30-min blocks from 8:00 (index 0) to 20:00 (index 24 excluded). So indices 0..23.
const _startHour = 8;
const _blockCount = 24;

int _timeToBlockIndex(String time) {
  final parts = time.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final totalMinutes = (h - _startHour) * 60 + m;
  if (totalMinutes < 0) return 0;
  final idx = totalMinutes ~/ 30;
  return idx >= _blockCount ? _blockCount - 1 : idx;
}

String _blockIndexToTime(int index) {
  final totalMinutes = index * 30;
  final h = _startHour + totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// For one day, get set of filled block indices from slots.
Set<int> _filledBlocksForDay(int dayOfWeek, List<AvailabilitySlot> slots) {
  final set = <int>{};
  for (final s in slots) {
    if (s.dayOfWeek != dayOfWeek) continue;
    final startIdx = _timeToBlockIndex(s.start);
    final endIdx = _timeToBlockIndex(s.end);
    for (var i = startIdx; i < endIdx; i++) set.add(i);
  }
  return set;
}

/// Merge filled block indices for one day into AvailabilitySlots (consecutive runs).
List<AvailabilitySlot> _blocksToSlotsForDay(int dayOfWeek, Set<int> filled) {
  if (filled.isEmpty) return [];
  final sorted = filled.toList()..sort();
  final result = <AvailabilitySlot>[];
  var runStart = sorted.first;
  var runEnd = runStart;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] == runEnd + 1) {
      runEnd = sorted[i];
    } else {
      result.add(AvailabilitySlot(
        dayOfWeek: dayOfWeek,
        start: _blockIndexToTime(runStart),
        end: _blockIndexToTime(runEnd + 1),
      ));
      runStart = sorted[i];
      runEnd = runStart;
    }
  }
  result.add(AvailabilitySlot(
    dayOfWeek: dayOfWeek,
    start: _blockIndexToTime(runStart),
    end: _blockIndexToTime(runEnd + 1),
  ));
  return result;
}

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({super.key});

  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  int _selectedDayOfWeek = 1; // 1 = Mon

  @override
  Widget build(BuildContext context) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
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
                        const SizedBox(height: 24),
                        Text(
                          'Weekly calendar',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap a time to toggle availability for the selected day.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 12),
                        _DaySelector(
                          selectedDayOfWeek: _selectedDayOfWeek,
                          onSelect: (d) => setState(() => _selectedDayOfWeek = d),
                        ),
                        const SizedBox(height: 12),
                        _TimeGrid(
                          selectedDayOfWeek: _selectedDayOfWeek,
                          slots: slots,
                          onToggle: (int blockIndex) async {
                            final filled = _filledBlocksForDay(_selectedDayOfWeek, slots);
                            if (filled.contains(blockIndex)) {
                              filled.remove(blockIndex);
                            } else {
                              filled.add(blockIndex);
                            }
                            final daySlots = _blocksToSlotsForDay(_selectedDayOfWeek, filled);
                            final otherSlots = slots.where((s) => s.dayOfWeek != _selectedDayOfWeek).toList();
                            final updated = [...otherSlots, ...daySlots];
                            await fs.setAvailability(activeId, updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Availability updated')),
                              );
                            }
                          },
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

  void _showAddSlotDialog(BuildContext context, WidgetRef ref, String providerId, List<AvailabilitySlot> current, FirestoreService fs) {
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

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDayOfWeek, required this.onSelect});

  final int selectedDayOfWeek;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = selectedDayOfWeek == day;
        return Material(
          color: isSelected
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => onSelect(day),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                _dayLetters[i],
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.selectedDayOfWeek,
    required this.slots,
    required this.onToggle,
  });

  final int selectedDayOfWeek;
  final List<AvailabilitySlot> slots;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final filled = _filledBlocksForDay(selectedDayOfWeek, slots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_blockCount, (index) {
        final isAvailable = filled.contains(index);
        final timeLabel = _blockIndexToTime(index);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  _formatTimeLabel(timeLabel),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ),
              Expanded(
                child: Material(
                  color: isAvailable
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => onToggle(index),
                    borderRadius: BorderRadius.circular(4),
                    child: const SizedBox(height: 28),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _formatTimeLabel(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final ampm = h < 12 ? 'am' : 'pm';
    return '$hour:$m $ampm';
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
