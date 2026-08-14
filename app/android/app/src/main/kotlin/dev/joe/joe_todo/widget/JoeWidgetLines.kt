package dev.joe.joe_todo.widget

import java.util.Calendar

/**
 * Eine Zeile in einer Widget-Liste, fertig ausgerechnet.
 *
 * [Kind.HEAD] ist die Tagesueberschrift ("Heute", "Mi, 20. Aug"),
 * [Kind.ENTRY] eine Aufgabe oder ein Termin, [Kind.MUTED] ein leiser Hinweis
 * ("+3 weitere") – der bleibt noetig, weil der Schnappschuss pro Tag nur die
 * ersten Eintraege mitbringt.
 */
internal class WidgetLine(
    val kind: Kind,
    val title: String,
    val lead: String? = null,
    val color: Int = 0,
    val done: Boolean = false,
) {
    enum class Kind { HEAD, ENTRY, MUTED }

    override fun equals(other: Any?): Boolean =
        other is WidgetLine && other.kind == kind && other.title == title &&
            other.lead == lead && other.color == color && other.done == done

    override fun hashCode(): Int =
        (((kind.hashCode() * 31 + title.hashCode()) * 31 +
            (lead?.hashCode() ?: 0)) * 31 + color) * 31 + done.hashCode()

    override fun toString(): String = "$kind($title, $lead)"
}

/**
 * Was in den Listen der Widgets steht.
 *
 * Reine Rechnerei auf dem Schnappschuss, ohne Android: die Listen scrollen,
 * es gibt also keinen Platz mehr zu verteilen und nichts wegzulassen. Genau
 * deshalb liegt das hier und nicht im Zeichnen – so ist die Reihenfolge
 * pruefbar, ohne ein Telefon zu fragen.
 */
internal object JoeWidgetLines {

    /** Wie weit der Blick nach vorn hoechstens sucht. Der Schnappschuss endet
     *  ohnehin frueher; das hier ist nur die Bremse. */
    private const val AHEAD_DAYS = 60

    /** Wie weit die Termine hoechstens vorausschauen. */
    private const val APPOINTMENT_DAYS = 400

    /**
     * Die Aufgaben von heute, danach der Blick nach vorn.
     *
     * Nach vorn gezeigt wird nur, was an dem Tag wirklich neu faellig ist:
     * die Tagesliste im Schnappschuss traegt Liegengebliebenes mit (so steht
     * es auch im Dashboard), und ohne diesen Filter stuende jede heute offene
     * Aufgabe hier an jedem einzelnen kommenden Tag noch einmal.
     */
    fun tasks(snapshot: WidgetSnapshot, today: Calendar): List<WidgetLine> {
        val lines = mutableListOf<WidgetLine>()
        val day = snapshot.day(JoeWidgetData.dayKey(today))
        if (day != null) {
            for (entry in day.tasks) lines.add(entry(entry, null))
            rest(day.taskCount, day.tasks.size)?.let {
                lines.add(WidgetLine(WidgetLine.Kind.MUTED, weitere(it)))
            }
        }

        val cursor = today.clone() as Calendar
        cursor.add(Calendar.DAY_OF_MONTH, 1)
        var days = 0
        while (days < AHEAD_DAYS) {
            val key = JoeWidgetData.dayKey(cursor)
            if (!snapshot.covers(key)) break
            val due = snapshot.marked(key)?.tasks?.filter { !it.carried }.orEmpty()
            if (due.isNotEmpty()) {
                lines.add(head(cursor, today))
                for (entry in due) lines.add(entry(entry, null))
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1)
            days++
        }
        return lines
    }

    /**
     * Die naechsten Termine ab heute, nach Tagen gruppiert.
     *
     * Die Uhrzeit steht in der Zeile, das Datum in der Ueberschrift darueber –
     * in einer schmalen Spalte waere fuer beides in einer Zeile kein Platz.
     */
    fun appointments(snapshot: WidgetSnapshot, today: Calendar): List<WidgetLine> {
        val lines = mutableListOf<WidgetLine>()
        val cursor = today.clone() as Calendar
        var days = 0
        while (days < APPOINTMENT_DAYS) {
            val key = JoeWidgetData.dayKey(cursor)
            if (!snapshot.covers(key)) break
            val day = snapshot.marked(key)
            if (day != null && day.appointments.isNotEmpty()) {
                lines.add(head(cursor, today))
                for (entry in day.appointments) {
                    lines.add(entry(entry, JoeWidgetText.time(entry.minute)))
                }
                rest(day.appointmentCount, day.appointments.size)?.let {
                    lines.add(
                        WidgetLine(
                            WidgetLine.Kind.MUTED,
                            if (it == 1) "+1 weiterer Termin" else "+$it weitere Termine",
                        ),
                    )
                }
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1)
            days++
        }
        return lines
    }

    private fun entry(entry: WidgetEntry, lead: String?) = WidgetLine(
        WidgetLine.Kind.ENTRY,
        entry.title,
        lead,
        entry.color,
        entry.done,
    )

    private fun head(day: Calendar, today: Calendar) =
        WidgetLine(WidgetLine.Kind.HEAD, JoeWidgetText.relativeDay(day, today))

    /** Wie viele an dem Tag der Schnappschuss weggelassen hat, oder null. */
    private fun rest(total: Int, loaded: Int): Int? =
        if (total > loaded) total - loaded else null

    private fun weitere(count: Int) =
        if (count == 1) "+1 weiterer" else "+$count weitere"
}
