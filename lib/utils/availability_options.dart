import '../models/availability_slot.dart';

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class TimeOption {
  const TimeOption({
    required this.dayName,
    required this.timeLabel,
    required this.slotLabel,
    this.date,
    this.dateLabel,
  });
  final String dayName;
  final String timeLabel;
  final String slotLabel;
  final DateTime? date;
  final String? dateLabel;
}

/// Expand recurring slots into 30-min start-time options. Deduplicated by slotLabel.
List<TimeOption> expandSlotsToTimeOptions(List<AvailabilitySlot> slots) {
  final result = <TimeOption>[];
  final seen = <String>{};
  for (final s in slots) {
    final dayName = s.dayOfWeek >= 1 && s.dayOfWeek <= 7 ? dayNames[s.dayOfWeek - 1] : 'Day${s.dayOfWeek}';
    final startParts = s.start.split(':');
    final endParts = s.end.split(':');
    final startH = int.tryParse(startParts.isNotEmpty ? startParts[0] : '') ?? 0;
    final startM = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;
    final endH = int.tryParse(endParts.isNotEmpty ? endParts[0] : '') ?? 0;
    final endM = int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0;
    var totalMin = startH * 60 + startM;
    final endTotal = endH * 60 + endM;
    while (totalMin < endTotal) {
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      final ampm = h < 12 ? 'am' : 'pm';
      final timeLabel = '$hour12:${m.toString().padLeft(2, '0')} $ampm';
      final slotLabel = '$dayName $timeLabel';
      if (!seen.contains(slotLabel)) {
        seen.add(slotLabel);
        result.add(TimeOption(dayName: dayName, timeLabel: timeLabel, slotLabel: slotLabel));
      }
      totalMin += 30;
    }
  }
  return result;
}

/// Monday of the week containing [d].
DateTime _mondayOf(DateTime d) {
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Expand recurring slots into time options with concrete dates for [numWeeks] starting from [startDate].
/// Each option has [date] and [dateLabel] (e.g. "Mon, Mar 3") and [slotLabel] like "Mar 3, 2025 2:00 PM".
List<TimeOption> expandSlotsToTimeOptionsWithDates(
  List<AvailabilitySlot> slots,
  DateTime startDate,
  int numWeeks,
) {
  final result = <TimeOption>[];
  final seen = <String>{};
  final startMonday = _mondayOf(startDate);

  for (var w = 0; w < numWeeks; w++) {
    final weekStart = startMonday.add(Duration(days: w * 7));
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = weekStart.add(Duration(days: dayOffset));
      final dayOfWeek = date.weekday;
      final dayName = dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek - 1] : 'Day$dayOfWeek';
      final dateLabel = '${dayName}, ${_monthNames[date.month - 1]} ${date.day}';

      for (final s in slots) {
        if (s.dayOfWeek != dayOfWeek) continue;
        final startParts = s.start.split(':');
        final endParts = s.end.split(':');
        final startH = int.tryParse(startParts.isNotEmpty ? startParts[0] : '') ?? 0;
        final startM = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;
        final endH = int.tryParse(endParts.isNotEmpty ? endParts[0] : '') ?? 0;
        final endM = int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0;
        var totalMin = startH * 60 + startM;
        final endTotal = endH * 60 + endM;
        while (totalMin < endTotal) {
          final h = totalMin ~/ 60;
          final m = totalMin % 60;
          final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
          final ampm = h < 12 ? 'am' : 'pm';
          final timeLabel = '$hour12:${m.toString().padLeft(2, '0')} $ampm';
          final slotLabel = '${_monthNames[date.month - 1]} ${date.day}, ${date.year} $timeLabel';
          if (!seen.contains(slotLabel)) {
            seen.add(slotLabel);
            result.add(TimeOption(
              dayName: dayName,
              timeLabel: timeLabel,
              slotLabel: slotLabel,
              date: date,
              dateLabel: dateLabel,
            ));
          }
          totalMin += 30;
        }
      }
    }
  }
  return result;
}
