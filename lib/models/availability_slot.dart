/// One recurring weekly slot: dayOfWeek 1=Mon..7=Sun, start/end as "HH:mm".
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.start,
    required this.end,
  });

  final int dayOfWeek;
  final String start;
  final String end;

  Map<String, dynamic> toMap() => {
        'dayOfWeek': dayOfWeek,
        'start': start,
        'end': end,
      };

  factory AvailabilitySlot.fromMap(Map<String, dynamic> m) => AvailabilitySlot(
        dayOfWeek: m['dayOfWeek'] as int? ?? 1,
        start: m['start'] as String? ?? '09:00',
        end: m['end'] as String? ?? '17:00',
      );
}
