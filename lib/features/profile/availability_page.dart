import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/availability_slot.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _startHour = 7;
const _endHour = 22; // 10 PM

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({super.key});

  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  late DateTime _weekStart;
  int _selectedDayIndex = 0; // 0=Mon .. 6=Sun

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _selectedDayIndex = now.weekday - 1;
  }

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  @override
  Widget build(BuildContext context) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const Text(
          'Schedule Availability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(child: Text('Sign in to set your availability.'));
          }
          if (fs == null) return const Center(child: Text('Firebase not configured.'));

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
                  return _ScheduleBody(
                    weekStart: _weekStart,
                    selectedDayIndex: _selectedDayIndex,
                    slots: slots,
                    activeId: activeId,
                    onSelectDay: (i) => setState(() => _selectedDayIndex = i),
                    onPrevWeek: _prevWeek,
                    onNextWeek: _nextWeek,
                    onAddSlot: (slot) async {
                      final updated = [...slots, slot];
                      await fs.setAvailability(activeId, updated);
                    },
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
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.weekStart,
    required this.selectedDayIndex,
    required this.slots,
    required this.activeId,
    required this.onSelectDay,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onAddSlot,
  });

  final DateTime weekStart;
  final int selectedDayIndex;
  final List<AvailabilitySlot> slots;
  final String activeId;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final Future<void> Function(AvailabilitySlot) onAddSlot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Stack(
      children: [
        Column(
          children: [
            // Week selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: onPrevWeek,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(7, (i) {
                        final date = weekStart.add(Duration(days: i));
                        final isToday = date.year == now.year &&
                            date.month == now.month &&
                            date.day == now.day;
                        final isSelected = i == selectedDayIndex;

                        return GestureDetector(
                          onTap: () => onSelectDay(i),
                          child: Column(
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.black : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Colors.red
                                      : isSelected
                                          ? Colors.grey[200]
                                          : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isToday ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: onNextWeek,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Time grid
            Expanded(
              child: _TimeGrid(
                dayOfWeek: selectedDayIndex + 1, // 1=Mon
                slots: slots,
              ),
            ),
          ],
        ),

        // FAB
        Positioned(
          bottom: 90,
          right: 20,
          child: FloatingActionButton(
            onPressed: () => _showAddAvailabilityDialog(context),
            backgroundColor: const Color(0xFF2D2D2D),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showAddAvailabilityDialog(BuildContext context) {
    var startHour = 10;
    var startMinute = 0;
    var startPeriod = 'AM';
    var endHour = 3;
    var endMinute = 0;
    var endPeriod = 'PM';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String formatTime(int h, int m, String p) {
            return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $p';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Center(
              child: Text('Add Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TimeChip(
                      label: formatTime(startHour, startMinute, startPeriod),
                      active: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('to', style: TextStyle(fontSize: 14)),
                    ),
                    _TimeChip(
                      label: formatTime(endHour, endMinute, endPeriod),
                      active: false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Simple time pickers using dropdowns
                Row(
                  children: [
                    const Text('Start: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: startHour,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                      onChanged: (v) => setDialogState(() => startHour = v!),
                    ),
                    const Text(':'),
                    DropdownButton<int>(
                      value: startMinute,
                      items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(),
                      onChanged: (v) => setDialogState(() => startMinute = v!),
                    ),
                    DropdownButton<String>(
                      value: startPeriod,
                      items: ['AM', 'PM'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setDialogState(() => startPeriod = v!),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('End:   ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: endHour,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                      onChanged: (v) => setDialogState(() => endHour = v!),
                    ),
                    const Text(':'),
                    DropdownButton<int>(
                      value: endMinute,
                      items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(),
                      onChanged: (v) => setDialogState(() => endMinute = v!),
                    ),
                    DropdownButton<String>(
                      value: endPeriod,
                      items: ['AM', 'PM'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setDialogState(() => endPeriod = v!),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final startH24 = startPeriod == 'PM' && startHour != 12
                        ? startHour + 12
                        : (startPeriod == 'AM' && startHour == 12 ? 0 : startHour);
                    final endH24 = endPeriod == 'PM' && endHour != 12
                        ? endHour + 12
                        : (endPeriod == 'AM' && endHour == 12 ? 0 : endHour);

                    final startStr = '${startH24.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
                    final endStr = '${endH24.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

                    final slot = AvailabilitySlot(
                      dayOfWeek: selectedDayIndex + 1,
                      start: startStr,
                      end: endStr,
                    );
                    Navigator.pop(ctx);
                    await onAddSlot(slot);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Availability added')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Availability', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2D2D2D) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? const Color(0xFF2D2D2D) : Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

// ── Time Grid ───────────────────────────────────────────────────────────

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.dayOfWeek,
    required this.slots,
  });

  final int dayOfWeek;
  final List<AvailabilitySlot> slots;

  @override
  Widget build(BuildContext context) {
    final daySlots = slots.where((s) => s.dayOfWeek == dayOfWeek).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 12, right: 16, top: 8, bottom: 100),
      child: Column(
        children: List.generate(_endHour - _startHour, (i) {
          final hour = _startHour + i;
          final label = _hourLabel(hour);

          // Check if this hour falls within any availability slot
          final availSlot = _slotAtHour(daySlots, hour);

          return SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: availSlot != null
                        ? Container(
                            margin: const EdgeInsets.only(top: 1, bottom: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Available\n${_formatSlotTime(availSlot.start)} - ${_formatSlotTime(availSlot.end)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  AvailabilitySlot? _slotAtHour(List<AvailabilitySlot> daySlots, int hour) {
    for (final s in daySlots) {
      final startH = int.tryParse(s.start.split(':')[0]) ?? 0;
      final endH = int.tryParse(s.end.split(':')[0]) ?? 0;
      if (hour >= startH && hour < endH) return s;
    }
    return null;
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatSlotTime(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final mStr = m > 0 ? ':${m.toString().padLeft(2, '0')}' : '';
    if (h == 0) return '12${mStr}am';
    if (h < 12) return '$h${mStr}am';
    if (h == 12) return '12${mStr}pm';
    return '${h - 12}${mStr}pm';
  }
}
