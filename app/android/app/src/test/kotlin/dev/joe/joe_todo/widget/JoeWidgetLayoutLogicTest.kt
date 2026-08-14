package dev.joe.joe_todo.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JoeWidgetLayoutLogicTest {
    @Test
    fun `eine Datumsgruppe startet nie ohne Platz fuer Inhalt`() {
        assertFalse(JoeWidgetLayoutLogic.canStartGroup(used = 3, max = 4))
        assertTrue(JoeWidgetLayoutLogic.canStartGroup(used = 2, max = 4))
    }

    @Test
    fun `vollstaendige Termingruppe braucht keinen Resthinweis`() {
        assertEquals(
            AppointmentGroupPlan(entries = 2, hidden = 0, summaryOnly = false),
            JoeWidgetLayoutLogic.appointments(total = 2, loaded = 2, available = 3),
        )
    }

    @Test
    fun `abgeschnittene Termingruppe reserviert den Resthinweis`() {
        assertEquals(
            AppointmentGroupPlan(entries = 2, hidden = 3, summaryOnly = false),
            JoeWidgetLayoutLogic.appointments(total = 5, loaded = 5, available = 3),
        )
    }

    @Test
    fun `eine einzige freie Zeile fasst alle Termine zusammen`() {
        assertEquals(
            AppointmentGroupPlan(entries = 0, hidden = 4, summaryOnly = true),
            JoeWidgetLayoutLogic.appointments(total = 4, loaded = 4, available = 1),
        )
    }

    @Test
    fun `volle Zahl beruecksichtigt schon im Snapshot gekappte Termine`() {
        assertEquals(
            AppointmentGroupPlan(entries = 3, hidden = 10, summaryOnly = false),
            JoeWidgetLayoutLogic.appointments(total = 13, loaded = 12, available = 4),
        )
    }
}
