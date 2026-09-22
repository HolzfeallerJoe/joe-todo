# Welle 0 – Ergebnis (Grundlage fuer Welle 1)

Gemergt auf main (d5185c3). `flutter analyze` sauber, `flutter test` 266 gruen,
1 bekannter Fehler: `legibility_test.dart` „Kalender: leerer Tag“ haengt vom
heutigen Datum ab (Mondhauptphase/Feiertag). Reparatur gehoert Strang 1d.

## Abweichungen von den Plaenen (0a)
- widgets.dart, Aufgabenblatt speichern: eine schon woechentliche Aufgabe behaelt beim Bearbeiten ihre Tage; nur neue Aufgaben bekommen `{date.weekday}` (vorlaeufig, bis 1a die Wochenskala baut). „Woechentlich“ ist derzeit noch ein eigener Chip.
- `spanDays` beim Laden auf `Task.maxStoredSpanDays = 365` begrenzt.
- `startsOn`/`recurrenceLabel` fallen auf den Wochentag des Starts zurueck, wenn `weekdays` leer ist.
- `setPriorityColor`: Index ausserhalb der Palette wirkt wie `null`.
- Wiederkehrende Aufgaben werden unter dem Starttag der Wiederholung abgehakt.

## Uebergaben an Welle 1
- **1a:** Wochenskala im Blatt ersetzt die vorlaeufige Speicherregel und den Chip „Woechentlich“. `Task.weekdaysLabel` nutzen.
- **1b:** `home_widget.dart` `widgetTasksForDay` prueft „ueberfaellig“ noch ueber `startDate`, soll `task.lastDay` nehmen. Termine liefern `'minute'` noch an jedem Tag der Spanne. Ganztagstermine in `test/agenda_test.dart` lokal statt UTC bauen (Plugin liefert lokale Mitternacht).
- **1d:** `legibility_test` „Kalender: leerer Tag“ vom Datum unabhaengig machen (festes Datum ohne Mondhauptphase/Feiertag oder Mondanzeige aus).

## Oeffentliche API aus 0a
```dart
// util.dart
int calendarDaysBetween(DateTime from, DateTime to);
DateTime addCalendarDays(DateTime d, int days);
String formatHm(DateTime d);                     // "12:00"
String formatSpan(DateTime start, DateTime end); // "12:00 – 18:00 Uhr" | "Mo, 14. Sep 12:00 – Do, 17. Sep 18:00"

// models.dart
enum RecurrenceType { none, weekly, monthly, yearly, everyXDays }
const allWeekdays = {1,2,3,4,5,6,7};
// Task: neue Felder weekdays (Set<int>), spanDays (int), startMinute, endMinute (int?) – alle optional im Konstruktor
bool startsOn(DateTime day);  bool occursOn(DateTime day);
bool get hasDuration;  DateTime get lastDay;
DateTime? occurrenceStartFor(DateTime day);
({DateTime start, DateTime end}) spanOf(DateTime occurrenceStart);
static int maxSpanDays(RecurrenceType r, Set<int> weekdays, int intervalDays);
static String weekdaysLabel(Set<int> days);
static const maxStoredSpanDays = 365;
Color get ownColor;   Color get color;       // color = wirksame Farbe (mit Prioritaetsfarbe)
// Appointment
DateTime? end;  DateTime get lastDay;  bool coversDay(DateTime day);
// PriorityColors (statisch)
static int? of(Priority p); static void use(Map<Priority,int> c); static void reset();
// ShoppingListMode { tab, perDay } mit .label, .description, fromJson
// ShoppingItem { id, title, done, day?, createdAt }
// AppState
Map<Priority,int> priorityColors;  void setPriorityColor(Priority p, int? index);
double petScale;                   void setPetScale(double v);
List<ShoppingItem> shopping;  ShoppingListMode shoppingMode;
List<ShoppingItem> shoppingItemsFor(DateTime? day);
ShoppingItem? addShoppingItem(String title, {DateTime? day});
void toggleShoppingItem(ShoppingItem); void renameShoppingItem(ShoppingItem, String);
void deleteShoppingItem(ShoppingItem); void setShoppingMode(ShoppingListMode);

// pets.dart
const minPetScale = 0.6, maxPetScale = 1.6;
petBox(pet, spot, {double scale = 1});  petOverlap(pet, spot, page, {double scale = 1});
PetPage.shopping   // nur Plaetze oben

// device_calendar.dart (0b)
String deviceEventTimeLabel(event, DateTime day); // Starttag Uhrzeit, Folgetage/ganztaegig „ganztägig“
```
