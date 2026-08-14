package dev.joe.joe_todo.widget

import java.util.Calendar

/**
 * Die Namen und Datumsformate der Widgets.
 *
 * Deutsch, wie ueberall in Joe (lib/util.dart) – und ohne Locale-Gerate: ein
 * Telefon auf Englisch soll im Widget nicht ploetzlich "Mon" sagen, waehrend
 * die App daneben "Mo" schreibt.
 *
 * Eigene Datei, weil beides an zwei Stellen gebraucht wird: beim Zeichnen
 * (JoeWidgetViews) und beim Fuellen der scrollbaren Listen
 * (JoeWidgetLines), und die laufen in verschiedenen Prozessen.
 */
internal object JoeWidgetText {

    val WEEKDAYS = arrayOf("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So")

    val MONTHS = arrayOf(
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    )

    private val MONTHS_SHORT = arrayOf(
        "Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
        "Jul", "Aug", "Sep", "Okt", "Nov", "Dez",
    )

    /** Der Wochentag als Spalte, Montag zuerst – wie im Kalender der App. */
    fun mondayFirst(cal: Calendar): Int = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

    /** "15:00" aus der Minute seit Mitternacht. */
    fun time(minute: Int): String? {
        if (minute < 0 || minute >= 24 * 60) return null
        val hour = minute / 60
        val rest = minute % 60
        return "${if (hour < 10) "0$hour" else "$hour"}:${if (rest < 10) "0$rest" else "$rest"}"
    }

    /** "20. Aug" */
    fun shortDate(day: Calendar): String =
        "${day.get(Calendar.DAY_OF_MONTH)}. ${MONTHS_SHORT[day.get(Calendar.MONTH)]}"

    /** "Heute", "Morgen", sonst "Mi, 20. Aug" – wie formatRelativeDay in der App. */
    fun relativeDay(day: Calendar, today: Calendar): String {
        val key = JoeWidgetData.dayKey(day)
        if (key == JoeWidgetData.dayKey(today)) return "Heute"
        val tomorrow = today.clone() as Calendar
        tomorrow.add(Calendar.DAY_OF_MONTH, 1)
        if (key == JoeWidgetData.dayKey(tomorrow)) return "Morgen"
        return "${WEEKDAYS[mondayFirst(day)]}, ${shortDate(day)}"
    }

    fun month(day: Calendar): String =
        "${MONTHS[day.get(Calendar.MONTH)]} ${day.get(Calendar.YEAR)}"
}
