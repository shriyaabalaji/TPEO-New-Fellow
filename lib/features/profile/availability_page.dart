import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/availability_slot.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _startHour = 7;

/// Drag range preview while the user pans on the grid (start/current hour).
class _DragHourPair {
  const _DragHourPair(this.start, this.current);
  final int start;
  final int current;
}
const _dayViewEndHour = 21; // 9 PM

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
    _selectedDayIndex = (now.weekday - 1).clamp(0, 6);
  }

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  void _setMonthYear(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    setState(() {
      _weekStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
      _selectedDayIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(context, title: 'Schedule Availability'),
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
                    onSetMonthYear: _setMonthYear,
                    onSaveSlots: (updated) async {
                      await fs.setAvailability(activeId, _normalizeSlots(updated));
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
    required this.onSetMonthYear,
    required this.onSaveSlots,
  });

  final DateTime weekStart;
  final int selectedDayIndex;
  final List<AvailabilitySlot> slots;
  final String activeId;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final void Function(int year, int month) onSetMonthYear;
  final Future<void> Function(List<AvailabilitySlot>) onSaveSlots;

  @override
  Widget build(BuildContext context) {
    return _InteractiveScheduleBody(
      weekStart: weekStart,
      selectedDayIndex: selectedDayIndex,
      slots: slots,
      onSelectDay: onSelectDay,
      onPrevWeek: onPrevWeek,
      onNextWeek: onNextWeek,
      onSetMonthYear: onSetMonthYear,
      onSaveSlots: onSaveSlots,
    );
  }
}

class _InteractiveScheduleBody extends StatefulWidget {
  const _InteractiveScheduleBody({
    required this.weekStart,
    required this.selectedDayIndex,
    required this.slots,
    required this.onSelectDay,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSetMonthYear,
    required this.onSaveSlots,
  });

  final DateTime weekStart;
  final int selectedDayIndex;
  final List<AvailabilitySlot> slots;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final void Function(int year, int month) onSetMonthYear;
  final Future<void> Function(List<AvailabilitySlot>) onSaveSlots;

  @override
  State<_InteractiveScheduleBody> createState() => _InteractiveScheduleBodyState();
}

class _InteractiveScheduleBodyState extends State<_InteractiveScheduleBody> {
  /// Drag preview only — avoids setState on every pan tick (which can cancel the gesture).
  final ValueNotifier<_DragHourPair?> _dragPreview = ValueNotifier(null);

  int get _selectedDayOfWeek => widget.selectedDayIndex + 1;

  @override
  void dispose() {
    _dragPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: widget.onPrevWeek,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _MonthYearDropdown(
                        weekStart: widget.weekStart,
                        onChanged: widget.onSetMonthYear,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: widget.onNextWeek,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -300) widget.onNextWeek();
                if (v > 300) widget.onPrevWeek();
              },
              child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final date = widget.weekStart.add(Duration(days: i));
                  final isSelected = i == widget.selectedDayIndex;
                  return GestureDetector(
                    onTap: () => widget.onSelectDay(i),
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i],
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2D2D2D) : const Color(0xFFF4F4F4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _DayDragGrid(
                    dayOfWeek: _selectedDayOfWeek,
                    slots: widget.slots,
                    dragPreview: _dragPreview,
                    onDragStartHour: (h) {
                      _dragPreview.value = _DragHourPair(h, h);
                    },
                    onDragUpdateHour: (h) {
                      final v = _dragPreview.value;
                      if (v != null) {
                        _dragPreview.value = _DragHourPair(v.start, h);
                      }
                    },
                    onDragCancel: () {
                      _dragPreview.value = null;
                    },
                    onDragEnd: () async {
                      final v = _dragPreview.value;
                      _dragPreview.value = null;
                      if (v == null) return;
                      final a = v.start;
                      final b = v.current;
                      final start = a <= b ? a : b;
                      final end = (a <= b ? b : a) + 1;
                      final updated = _toggleDayRange(
                        source: widget.slots,
                        dayOfWeek: _selectedDayOfWeek,
                        startHour: start,
                        endHour: end,
                      );
                      await widget.onSaveSlots(updated);
                    },
                  ),
            ),
          ],
        ),
        Positioned(
          bottom: 24,
          right: 18,
          child: GestureDetector(
            onTap: () => _showAddAvailabilityOverlay(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF2D2D2D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddAvailabilityOverlay(BuildContext context) {
    var startHour = 10;
    var startMinute = 0;
    var startPeriod = 'AM';
    var endHour = 3;
    var endMinute = 0;
    var endPeriod = 'PM';
    var editingStart = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String formatTime(int h, int m, String p) {
            final mm = m.toString().padLeft(2, '0');
            return '$h:$mm $p';
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 12,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.viewPaddingOf(ctx).bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Availability',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _overlayTimeChip(
                        label: formatTime(startHour, startMinute, startPeriod),
                        selected: editingStart,
                        onTap: () => setDialogState(() => editingStart = true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('to', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: _overlayTimeChip(
                        label: formatTime(endHour, endMinute, endPeriod),
                        selected: !editingStart,
                        onTap: () => setDialogState(() => editingStart = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: _InlineTimeWheelPicker(
                    hour: editingStart ? startHour : endHour,
                    minute: editingStart ? startMinute : endMinute,
                    period: editingStart ? startPeriod : endPeriod,
                    onChanged: (h, m, p) {
                      setDialogState(() {
                        if (editingStart) {
                          startHour = h; startMinute = m; startPeriod = p;
                        } else {
                          endHour = h; endMinute = m; endPeriod = p;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
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
                      final startMins = startH24 * 60 + startMinute;
                      final endMins = endH24 * 60 + endMinute;
                      if (endMins <= startMins) return;
                      final updated = [
                        ...widget.slots,
                        AvailabilitySlot(
                          dayOfWeek: _selectedDayOfWeek,
                          start: '${startH24.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}',
                          end: '${endH24.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
                        ),
                      ];
                      Navigator.pop(ctx);
                      await widget.onSaveSlots(updated);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Add Availability', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: Color(0xFF222222), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.black)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overlayTimeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E3237) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF2E3237) : const Color(0xFF1A1A1A),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 35 / 2,
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

List<AvailabilitySlot> _toggleDayRange({
  required List<AvailabilitySlot> source,
  required int dayOfWeek,
  required int startHour,
  required int endHour,
}) {
  final result = <AvailabilitySlot>[];
  var hadOverlap = false;

  for (final s in source) {
    if (s.dayOfWeek != dayOfWeek) {
      result.add(s);
      continue;
    }
    final sStart = _parseHour(s.start);
    final sEnd = _parseHour(s.end);
    final overlaps = sStart < endHour && sEnd > startHour;
    if (!overlaps) {
      result.add(s);
      continue;
    }
    hadOverlap = true;
    if (sStart < startHour) {
      result.add(AvailabilitySlot(
        dayOfWeek: dayOfWeek,
        start: '${sStart.toString().padLeft(2, '0')}:00',
        end: '${startHour.toString().padLeft(2, '0')}:00',
      ));
    }
    if (sEnd > endHour) {
      result.add(AvailabilitySlot(
        dayOfWeek: dayOfWeek,
        start: '${endHour.toString().padLeft(2, '0')}:00',
        end: '${sEnd.toString().padLeft(2, '0')}:00',
      ));
    }
  }

  if (!hadOverlap) {
    result.add(AvailabilitySlot(
      dayOfWeek: dayOfWeek,
      start: '${startHour.toString().padLeft(2, '0')}:00',
      end: '${endHour.toString().padLeft(2, '0')}:00',
    ));
  }

  return _normalizeSlots(result);
}

class _InlineTimeWheelPicker extends StatelessWidget {
  const _InlineTimeWheelPicker({
    required this.hour,
    required this.minute,
    required this.period,
    required this.onChanged,
  });

  final int hour;
  final int minute;
  final String period;
  final void Function(int hour, int minute, String period) onChanged;

  @override
  Widget build(BuildContext context) {
    final hourController = FixedExtentScrollController(initialItem: hour - 1);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final periodController = FixedExtentScrollController(initialItem: period == 'AM' ? 0 : 1);

    return Row(
      children: [
        Expanded(
          child: CupertinoPicker(
            key: ValueKey('hour-$hour-$minute-$period'),
            itemExtent: 38,
            diameterRatio: 1.2,
            scrollController: hourController,
            onSelectedItemChanged: (i) => onChanged(i + 1, minute, period),
            children: List.generate(12, (i) => Center(
              child: Text('${i + 1}', style: const TextStyle(fontSize: 18)),
            )),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            key: ValueKey('minute-$hour-$minute-$period'),
            itemExtent: 38,
            diameterRatio: 1.2,
            scrollController: minuteController,
            onSelectedItemChanged: (i) => onChanged(hour, i, period),
            children: List.generate(60, (i) => Center(
              child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)),
            )),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            key: ValueKey('period-$hour-$minute-$period'),
            itemExtent: 38,
            diameterRatio: 1.2,
            scrollController: periodController,
            onSelectedItemChanged: (i) => onChanged(hour, minute, i == 0 ? 'AM' : 'PM'),
            children: const [
              Center(child: Text('AM', style: TextStyle(fontSize: 18))),
              Center(child: Text('PM', style: TextStyle(fontSize: 18))),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthYearDropdown extends StatelessWidget {
  const _MonthYearDropdown({
    required this.weekStart,
    required this.onChanged,
  });

  final DateTime weekStart;
  final void Function(int year, int month) onChanged;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minYear = now.year - 2;
    final maxYear = now.year + 3;
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: weekStart.month,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: List.generate(
            12,
            (i) => DropdownMenuItem<int>(
              value: i + 1,
              child: Text(_months[i]),
            ),
          ),
          onChanged: (m) {
            if (m == null) return;
            onChanged(weekStart.year, m);
          },
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: weekStart.year.clamp(minYear, maxYear),
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: years
              .map((y) => DropdownMenuItem<int>(
                    value: y,
                    child: Text('$y'),
                  ))
              .toList(),
          onChanged: (y) {
            if (y == null) return;
            onChanged(y, weekStart.month);
          },
        ),
      ],
    );
  }
}

class _DayDragGrid extends StatelessWidget {
  const _DayDragGrid({
    required this.dayOfWeek,
    required this.slots,
    required this.dragPreview,
    required this.onDragStartHour,
    required this.onDragUpdateHour,
    required this.onDragCancel,
    required this.onDragEnd,
  });

  final int dayOfWeek;
  final List<AvailabilitySlot> slots;
  final ValueNotifier<_DragHourPair?> dragPreview;
  final ValueChanged<int> onDragStartHour;
  final ValueChanged<int> onDragUpdateHour;
  final VoidCallback onDragCancel;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final daySlots = slots.where((s) => s.dayOfWeek == dayOfWeek).toList();
    return LayoutBuilder(
      builder: (context, c) {
        const totalRows = _dayViewEndHour - _startHour + 1;
        final availableH = c.maxHeight.isFinite
            ? c.maxHeight
            : (35.0 * totalRows);
        final rowH = availableH / totalRows;
        final gridH = rowH * totalRows;
        return Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: SizedBox(
            height: gridH,
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Column(
                    children: List.generate(totalRows, (i) {
                      final h = _startHour + i;
                      return SizedBox(
                        height: rowH,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            _hourLabel(h),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => onDragStartHour(_hourAtOffset(d.localPosition.dy, rowH)),
                    onPanUpdate: (d) => onDragUpdateHour(_hourAtOffset(d.localPosition.dy, rowH)),
                    onPanCancel: onDragCancel,
                    onPanEnd: (_) => onDragEnd(),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE7E7E7)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ValueListenableBuilder<_DragHourPair?>(
                        valueListenable: dragPreview,
                        builder: (context, preview, _) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GridLinePainter(
                                    totalRows: totalRows,
                                    lineColor: const Color(0xFFECECEC),
                                  ),
                                ),
                              ),
                              ...daySlots.map((s) => _slotBlock(
                                    s,
                                    rowH,
                                    const Color(0xFF35A352),
                                  )),
                              if (preview != null)
                                _dragBlock(
                                  preview.start,
                                  preview.current,
                                  rowH,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Positioned _slotBlock(AvailabilitySlot s, double rowH, Color color) {
    final start = _parseHour(s.start).clamp(_startHour, _dayViewEndHour);
    final end = _parseHour(s.end).clamp(_startHour + 1, _dayViewEndHour + 1);
    final top = (start - _startHour) * rowH;
    final height = (end - start) * rowH;
    return Positioned(
      left: 2,
      right: 2,
      top: top,
      height: height,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Available',
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Positioned _dragBlock(int a, int b, double rowH) {
    final start = (a <= b ? a : b).clamp(_startHour, _dayViewEndHour);
    final end = ((a <= b ? b : a) + 1).clamp(_startHour + 1, _dayViewEndHour + 1);
    final top = (start - _startHour) * rowH;
    final height = (end - start) * rowH;
    return Positioned(
      left: 2,
      right: 2,
      top: top,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x8835A352),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF35A352)),
        ),
      ),
    );
  }

  int _hourAtOffset(double y, double rowH) {
    final idx = (y ~/ rowH).clamp(0, _dayViewEndHour - _startHour);
    return _startHour + idx;
  }
}

int _parseHour(String hhmm) => int.tryParse(hhmm.split(':').first) ?? 0;

String _hourLabel(int hour) {
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

List<AvailabilitySlot> _normalizeSlots(List<AvailabilitySlot> slots) {
  final byDay = <int, List<AvailabilitySlot>>{};
  for (final s in slots) {
    byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
  }
  final out = <AvailabilitySlot>[];
  byDay.forEach((day, list) {
    final ranges = list
        .map((s) => _HourRange(_parseHour(s.start), _parseHour(s.end)))
        .where((r) => r.end > r.start)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (ranges.isEmpty) return;
    var curStart = ranges.first.start;
    var curEnd = ranges.first.end;
    for (var i = 1; i < ranges.length; i++) {
      final r = ranges[i];
      if (r.start <= curEnd) {
        if (r.end > curEnd) curEnd = r.end;
      } else {
        out.add(AvailabilitySlot(
          dayOfWeek: day,
          start: '${curStart.toString().padLeft(2, '0')}:00',
          end: '${curEnd.toString().padLeft(2, '0')}:00',
        ));
        curStart = r.start;
        curEnd = r.end;
      }
    }
    out.add(AvailabilitySlot(
      dayOfWeek: day,
      start: '${curStart.toString().padLeft(2, '0')}:00',
      end: '${curEnd.toString().padLeft(2, '0')}:00',
    ));
  });
  return out;
}

class _GridLinePainter extends CustomPainter {
  const _GridLinePainter({required this.totalRows, required this.lineColor});
  final int totalRows;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;
    final rowH = size.height / totalRows;
    for (var i = 1; i <= totalRows; i++) {
      final y = rowH * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinePainter old) =>
      old.totalRows != totalRows || old.lineColor != lineColor;
}

class _HourRange {
  _HourRange(this.start, this.end);
  final int start;
  final int end;
}
