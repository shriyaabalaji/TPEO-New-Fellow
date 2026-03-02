import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/availability_slot.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';
// Display order to match reference: S M T W T F S (Sun first)
const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _displayOrder = [7, 1, 2, 3, 4, 5, 6]; // Sun=7, Mon=1, ..., Sat=6

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
  DateTime _selectedMonth;
  int _selectedWeekIndex = 0;
  late PageController _weekPageController;

  _AvailabilityPageState() : _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _selectedWeekIndex = _indexOfWeekContaining(DateTime.now());
    _weekPageController = PageController(initialPage: _selectedWeekIndex);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> _allWeekStarts() {
    final now = DateTime.now();
    final start = _mondayOf(DateTime(now.year - 1, now.month, 1));
    final end = _mondayOf(DateTime(now.year + 2, now.month, 1));
    final list = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 7))) {
      list.add(d);
    }
    return list;
  }

  int _indexOfWeekContaining(DateTime date) {
    final m = _mondayOf(date);
    final list = _allWeekStarts();
    for (var i = 0; i < list.length; i++) {
      if (list[i].isAtSameMomentAs(m)) return i;
      if (list[i].isAfter(m)) return i > 0 ? i - 1 : 0;
    }
    return list.length - 1;
  }

  int _indexOfFirstWeekInMonth(DateTime monthFirst) {
    final m = _mondayOf(DateTime(monthFirst.year, monthFirst.month, 1));
    final list = _allWeekStarts();
    for (var i = 0; i < list.length; i++) {
      if (!list[i].isBefore(m)) return i;
    }
    return list.length - 1;
  }

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
                        // Month dropdown
                        DropdownButton<DateTime>(
                          value: _selectedMonth,
                          isExpanded: false,
                          underline: const SizedBox(),
                          items: _monthDropdownItems(_selectedMonth),
                          onChanged: (d) {
                            if (d != null) {
                              final j = _indexOfFirstWeekInMonth(d);
                              setState(() {
                                _selectedMonth = d;
                                _selectedWeekIndex = j;
                              });
                              if (_weekPageController.hasClients) {
                                _weekPageController.jumpToPage(j);
                              }
                            }
                          },
                          itemHeight: 48,
                        ),
                        const SizedBox(height: 12),
                        // Week strip: dates on top, day letters below; scroll horizontally for next week
                        SizedBox(
                          height: 56,
                          child: PageView.builder(
                            controller: _weekPageController,
                            onPageChanged: (i) {
                              final weeks = _allWeekStarts();
                              if (i >= 0 && i < weeks.length) {
                                setState(() {
                                  _selectedWeekIndex = i;
                                  _selectedMonth = DateTime(weeks[i].year, weeks[i].month, 1);
                                });
                              }
                            },
                            itemCount: _allWeekStarts().length,
                            itemBuilder: (context, pageIndex) {
                              final weekStart = _allWeekStarts()[pageIndex];
                              return _WeekStrip(
                                weekStart: weekStart,
                                selectedDayOfWeek: _selectedDayOfWeek,
                                isSelectedWeek: pageIndex == _selectedWeekIndex,
                                onSelectDay: (dayOfWeek) {
                                  setState(() {
                                    _selectedDayOfWeek = dayOfWeek;
                                    _selectedWeekIndex = pageIndex;
                                    if (_weekPageController.hasClients && _weekPageController.page?.round() != pageIndex) {
                                      _weekPageController.animateToPage(pageIndex, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
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
}

String _monthName(DateTime d) {
  const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return m[d.month - 1];
}

List<DropdownMenuItem<DateTime>> _monthDropdownItems(DateTime selectedMonth) {
  final now = DateTime.now();
  final startYear = now.year <= selectedMonth.year ? now.year : selectedMonth.year;
  final endYear = (now.year + 1) >= selectedMonth.year ? now.year + 1 : selectedMonth.year;
  final items = <DropdownMenuItem<DateTime>>[];
  for (var y = startYear; y <= endYear; y++) {
    for (var m = 1; m <= 12; m++) {
      final d = DateTime(y, m, 1);
      items.add(DropdownMenuItem(
        value: d,
        child: Text('${_monthName(d)} $y'),
      ));
    }
  }
  return items;
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDayOfWeek,
    required this.isSelectedWeek,
    required this.onSelectDay,
  });

  final DateTime weekStart;
  final int selectedDayOfWeek;
  final bool isSelectedWeek;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final dayOfWeek = _displayOrder[i];
        final date = weekStart.add(Duration(days: i == 0 ? -1 : i - 1));
        final isSelected = isSelectedWeek && selectedDayOfWeek == dayOfWeek;
        return Expanded(
          child: Material(
            color: isSelected
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => onSelectDay(dayOfWeek),
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: isSelected ? 1.0 : 0.7),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dayLetters[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
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

  static String _hourLabel(int hour) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final ampm = hour < 12 ? 'am' : 'pm';
    return '$h$ampm';
  }

  @override
  Widget build(BuildContext context) {
    final filled = _filledBlocksForDay(selectedDayOfWeek, slots);
    const rowHeight = 28.0;
    const labelWidth = 44.0;
    final children = <Widget>[];
    for (var hour = 0; hour < 12; hour++) {
      final blockStart = hour * 2;
      // Two 30-min rows with one hour label on the left
      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            height: rowHeight * 2 + 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hourLabel(_startHour + hour),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildBlockRow(context, filled, blockStart, rowHeight),
                const SizedBox(height: 2),
                _buildBlockRow(context, filled, blockStart + 1, rowHeight),
              ],
            ),
          ),
        ],
      ));
      if (hour < 11) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: labelWidth, top: 4, bottom: 4),
          child: CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  static final Color _calendarAvailableOrange = Color(0xFFE65100); // Darker orange for visibility

  Widget _buildBlockRow(BuildContext context, Set<int> filled, int index, double height) {
    final isAvailable = filled.contains(index);
    return Material(
      color: isAvailable
          ? _calendarAvailableOrange
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () => onToggle(index),
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color ..strokeWidth = 1;
    const dashWidth = 6;
    const gap = 4;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth.clamp(0.0, size.width - x), 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
