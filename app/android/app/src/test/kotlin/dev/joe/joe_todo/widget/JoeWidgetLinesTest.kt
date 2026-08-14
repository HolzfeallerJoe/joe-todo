package dev.joe.joe_todo.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class JoeWidgetLinesTest {

    private val heute = Calendar.getInstance().apply {
        set(2026, Calendar.AUGUST, 14, 9, 0, 0)
        set(Calendar.MILLISECOND, 0)
    }

    private fun tag(offset: Int): String {
        val cal = heute.clone() as Calendar
        cal.add(Calendar.DAY_OF_MONTH, offset)
        return JoeWidgetData.dayKey(cal)
    }

    private fun aufgabe(title: String, carried: Boolean = false, done: Boolean = false) =
        WidgetEntry(title, 0xFF336699.toInt(), done, -1, carried)

    private fun termin(title: String, minute: Int) =
        WidgetEntry(title, 0xFF993366.toInt(), false, minute)

    private fun tagMit(
        tasks: List<WidgetEntry> = emptyList(),
        taskCount: Int = tasks.size,
        appointments: List<WidgetEntry> = emptyList(),
        appointmentCount: Int = appointments.size,
    ) = WidgetDay(tasks, taskCount, tasks.size, appointments, appointmentCount,
        false, null, null, false)

    private fun schnappschuss(days: Map<String, WidgetDay>, spanne: Int = 10) =
        WidgetSnapshot(tag(0), tag(spanne), WidgetTheme.fallback, days, 1)

    @Test
    fun `heute steht ohne Ueberschrift, die kommenden Tage mit`() {
        val lines = JoeWidgetLines.tasks(
            schnappschuss(
                mapOf(
                    tag(0) to tagMit(tasks = listOf(aufgabe("Blumen giessen"))),
                    tag(2) to tagMit(tasks = listOf(aufgabe("Wochenputz"))),
                ),
            ),
            heute,
        )

        assertEquals(
            listOf(
                WidgetLine(WidgetLine.Kind.ENTRY, "Blumen giessen", null, 0xFF336699.toInt()),
                WidgetLine(WidgetLine.Kind.HEAD, "So, 16. Aug"),
                WidgetLine(WidgetLine.Kind.ENTRY, "Wochenputz", null, 0xFF336699.toInt()),
            ),
            lines,
        )
    }

    @Test
    fun `morgen heisst Morgen`() {
        val lines = JoeWidgetLines.tasks(
            schnappschuss(mapOf(tag(1) to tagMit(tasks = listOf(aufgabe("Zahnarzt"))))),
            heute,
        )
        assertEquals(WidgetLine(WidgetLine.Kind.HEAD, "Morgen"), lines.first())
    }

    @Test
    fun `mitgeschlepptes taucht nicht an jedem kommenden Tag auf`() {
        // Die Tagesliste im Schnappschuss traegt Liegengebliebenes mit. Nach
        // vorn zaehlt aber nur, was an dem Tag wirklich neu faellig ist –
        // sonst stuende jede heute offene Aufgabe auch morgen da.
        val lines = JoeWidgetLines.tasks(
            schnappschuss(
                mapOf(
                    tag(1) to tagMit(
                        tasks = listOf(aufgabe("Von gestern", carried = true)),
                    ),
                ),
            ),
            heute,
        )
        assertTrue(lines.isEmpty())
    }

    @Test
    fun `was der Schnappschuss gekappt hat, sagt die letzte Zeile`() {
        val lines = JoeWidgetLines.tasks(
            schnappschuss(
                mapOf(
                    tag(0) to tagMit(
                        tasks = listOf(aufgabe("Eins"), aufgabe("Zwei")),
                        taskCount = 5,
                    ),
                ),
            ),
            heute,
        )
        assertEquals(WidgetLine(WidgetLine.Kind.MUTED, "+3 weitere"), lines.last())
    }

    @Test
    fun `Termine stehen mit Uhrzeit unter der Tagesueberschrift`() {
        val lines = JoeWidgetLines.appointments(
            schnappschuss(
                mapOf(tag(0) to tagMit(appointments = listOf(termin("Kaffee", 15 * 60)))),
            ),
            heute,
        )
        assertEquals(
            listOf(
                WidgetLine(WidgetLine.Kind.HEAD, "Heute"),
                WidgetLine(
                    WidgetLine.Kind.ENTRY, "Kaffee", "15:00", 0xFF993366.toInt(),
                ),
            ),
            lines,
        )
    }

    @Test
    fun `ein Tag ohne Termine bekommt keine Ueberschrift`() {
        val lines = JoeWidgetLines.appointments(
            schnappschuss(
                mapOf(
                    tag(0) to tagMit(tasks = listOf(aufgabe("Nur eine Aufgabe"))),
                    tag(3) to tagMit(appointments = listOf(termin("Zahnarzt", 9 * 60 + 30))),
                ),
            ),
            heute,
        )
        assertEquals(
            listOf(WidgetLine.Kind.HEAD, WidgetLine.Kind.ENTRY),
            lines.map { it.kind },
        )
    }

    @Test
    fun `hinter dem Zeitraum wird nicht weitergesucht`() {
        // Was jenseits von `to` liegt, ist nicht "leer", sondern unbekannt –
        // dort hoert die Liste auf.
        val lines = JoeWidgetLines.appointments(
            schnappschuss(
                days = mapOf(tag(5) to tagMit(appointments = listOf(termin("Zu spaet", 600)))),
                spanne = 2,
            ),
            heute,
        )
        assertTrue(lines.isEmpty())
    }
}
