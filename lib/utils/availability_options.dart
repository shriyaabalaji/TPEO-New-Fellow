import '../models/availability_slot.dart';

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class TimeOption {
  const TimeOption({required this.dayName, required this.timeLabel, required this.slotLabel});
  final String dayName;
  final String timeLabel;
  final String slotLabel;
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
