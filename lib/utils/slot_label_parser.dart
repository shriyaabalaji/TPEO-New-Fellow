/// Parses booking [slotLabel] strings produced by [expandSlotsToTimeOptionsWithDates],
/// e.g. `"Mar 3, 2025 2:00 PM"`, into a local start time. Returns null if the format is unknown.

const _monthAbbrev = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

class SlotTimeRange {
  const SlotTimeRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// If parsing succeeds, [end] is [start] + [durationMinutes].
SlotTimeRange? parseSlotLabelToRange(
  String slotLabel, {
  int durationMinutes = 30,
}) {
  final trimmed = slotLabel.trim();
  final re = RegExp(
    r'^([A-Za-z]{3})\s+(\d{1,2}),\s*(\d{4})\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
  );
  final m = re.firstMatch(trimmed);
  if (m == null) return null;
  final month = _monthAbbrev[m.group(1)];
  final day = int.tryParse(m.group(2) ?? '');
  final year = int.tryParse(m.group(3) ?? '');
  var hour = int.tryParse(m.group(4) ?? '');
  final minute = int.tryParse(m.group(5) ?? '');
  final ampm = (m.group(6) ?? '').toUpperCase();
  if (month == null || day == null || year == null || hour == null || minute == null) {
    return null;
  }
  if (ampm == 'PM' && hour < 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  final start = DateTime(year, month, day, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return SlotTimeRange(start: start, end: end);
}
