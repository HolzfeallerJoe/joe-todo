/// German date helpers — hand-rolled to avoid intl locale initialization.
const monthNames = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

const monthNamesShort = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];

const weekdayNames = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag',
];

const weekdayNamesShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

/// Kalendertage von [from] bis [to] (beides nur als Datum gelesen), an der
/// Sommerzeit-Grenze stabil: gezaehlt wird ueber UTC-Daten, nicht ueber eine
/// Dauer – zwischen zwei lokalen Mitternaechten liegen im Maerz nur 23 Stunden.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// [d] plus [days] Kalendertage, als lokales Datum.
DateTime addCalendarDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// "30. Juli"
String formatDate(DateTime d) => '${d.day}. ${monthNames[d.month - 1]}';

/// "30. Juli 2026"
String formatDateYear(DateTime d) => '${formatDate(d)} ${d.year}';

/// "Mittwoch, 30. Juli"
String formatDateFull(DateTime d) =>
    '${weekdayNames[d.weekday - 1]}, ${formatDate(d)}';

/// "15:00 Uhr"
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} Uhr';

String _two(int n) => n.toString().padLeft(2, '0');

/// "12:00"
String formatHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Eine Spanne fuer Listen und Blaetter:
///   gleicher Tag -> "12:00 – 18:00 Uhr"
///   sonst        -> "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00"
String formatSpan(DateTime start, DateTime end) {
  if (dateOnly(start) == dateOnly(end)) {
    return '${formatHm(start)} – ${formatHm(end)} Uhr';
  }
  String dayAndTime(DateTime d) => '${weekdayNamesShort[d.weekday - 1]}, '
      '${d.day}. ${monthNamesShort[d.month - 1]} ${formatHm(d)}';
  return '${dayAndTime(start)} – ${dayAndTime(end)}';
}

/// Relative day label: "Heute", "Morgen", otherwise "Mi, 30. Juli"
String formatRelativeDay(DateTime d) {
  final t = today();
  final day = dateOnly(d);
  if (day == t) return 'Heute';
  if (day == t.add(const Duration(days: 1))) return 'Morgen';
  return '${weekdayNamesShort[d.weekday - 1]}, ${formatDate(d)}';
}
