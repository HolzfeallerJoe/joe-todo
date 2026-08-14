package dev.joe.joe_todo.widget

/**
 * Reine Platzberechnung fuer eine Termingruppe. Sie lebt ausserhalb der
 * RemoteViews, damit die knappen Widget-Groessen ohne Android-Host testbar
 * bleiben.
 */
internal data class AppointmentGroupPlan(
    val entries: Int,
    val hidden: Int,
    val summaryOnly: Boolean,
)

internal object JoeWidgetLayoutLogic {
    /** Fuer eine Gruppe braucht es immer Ueberschrift plus mindestens eine
     *  informative Zeile. */
    fun canStartGroup(used: Int, max: Int): Boolean = used + 1 < max

    /** [available] sind die Zeilen unterhalb der bereits gesetzten
     *  Tagesueberschrift. Wenn nicht alles passt, wird eine Zeile fuer den
     *  Resthinweis reserviert. Bei genau einer freien Zeile ersetzt eine
     *  Zusammenfassung die Eintraege, damit nichts still verschwindet. */
    fun appointments(total: Int, loaded: Int, available: Int): AppointmentGroupPlan {
        if (available <= 0 || total <= 0 || loaded <= 0) {
            return AppointmentGroupPlan(0, 0, false)
        }
        val actualTotal = maxOf(total, loaded)
        if (actualTotal <= available) {
            return AppointmentGroupPlan(minOf(loaded, available), 0, false)
        }
        if (available == 1) {
            return AppointmentGroupPlan(0, actualTotal, true)
        }
        val entries = minOf(loaded, available - 1)
        return AppointmentGroupPlan(entries, actualTotal - entries, false)
    }
}
