package dev.joe.joe_todo.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class JoeWidgetColorsTest {

    private val paper = 0xFFFAF3E3.toInt()
    private val dunklesPapier = 0xFF1E1B18.toInt()

    @Test
    fun `eine Farbe mit genug Kontrast bleibt wie sie ist`() {
        val ink = 0xFF4A3527.toInt()
        assertEquals(ink, JoeWidgetColors.readable(ink, paper))
    }

    @Test
    fun `helles Gelb wird auf hellem Papier lesbar gemacht`() {
        val gelb = 0xFFFFE066.toInt()
        assertTrue(JoeWidgetColors.contrast(gelb, paper) < JoeWidgetColors.MIN_TEXT)

        val fix = JoeWidgetColors.readable(gelb, paper)
        assertTrue(JoeWidgetColors.contrast(fix, paper) >= JoeWidgetColors.MIN_TEXT)
    }

    @Test
    fun `der Farbton bleibt beim Abdunkeln erkennbar`() {
        val fix = JoeWidgetColors.readable(0xFFFFE066.toInt(), paper)
        val rot = (fix shr 16) and 0xFF
        val gruen = (fix shr 8) and 0xFF
        val blau = fix and 0xFF
        // Aus Gelb wird ein dunkleres Gelb und kein Grau: Rot und Gruen
        // liegen weiter deutlich vor Blau.
        assertTrue(rot > blau + 40)
        assertTrue(gruen > blau + 40)
        assertEquals(0xFF000000.toInt(), fix and 0xFF000000.toInt())
    }

    @Test
    fun `auf dunklem Papier wird aufgehellt statt abgedunkelt`() {
        val dunkelblau = 0xFF203050.toInt()
        val fix = JoeWidgetColors.readable(dunkelblau, dunklesPapier)
        assertTrue(JoeWidgetColors.contrast(fix, dunklesPapier) >= JoeWidgetColors.MIN_TEXT)
        assertTrue(JoeWidgetColors.luminance(fix) > JoeWidgetColors.luminance(dunkelblau))
    }

    @Test
    fun `ein Punkt darf heller bleiben als eine Zahl`() {
        val gelb = 0xFFFFE066.toInt()
        val alsPunkt = JoeWidgetColors.readable(gelb, paper, JoeWidgetColors.MIN_GLYPH)
        val alsZahl = JoeWidgetColors.readable(gelb, paper, JoeWidgetColors.MIN_TEXT)
        assertTrue(JoeWidgetColors.contrast(alsPunkt, paper) >= JoeWidgetColors.MIN_GLYPH)
        assertTrue(JoeWidgetColors.luminance(alsPunkt) > JoeWidgetColors.luminance(alsZahl))
    }

    @Test
    fun `es wird nur so weit gemischt wie noetig`() {
        val fix = JoeWidgetColors.readable(0xFFFFE066.toInt(), paper)
        // Deutlich ueber der Schwelle waere zu viel: dann bliebe vom Farbton
        // der Aufgabe nichts uebrig.
        assertTrue(JoeWidgetColors.contrast(fix, paper) < JoeWidgetColors.MIN_TEXT + 0.5)
    }

    @Test
    fun `was der Grund nicht hergibt bekommt das Beste was geht`() {
        // 21 ist der hoechstmoegliche Kontrast, und den gibt es nur zwischen
        // Schwarz und Weiss – auf dem Papier ist er nicht zu erreichen.
        val fix = JoeWidgetColors.readable(0xFF8A8A8A.toInt(), paper, minRatio = 21.0)
        assertEquals(0xFF000000.toInt(), fix)
    }

    @Test
    fun `ein mitteldunkler Grund wird abgedunkelt und nicht aufgehellt`() {
        // Grau mit halber Helligkeit traegt Schwarz noch besser als Weiss –
        // wer nur nach "hell oder dunkel" entscheidet, greift hier daneben.
        val grund = 0xFF767676.toInt()
        val fix = JoeWidgetColors.readable(0xFF8A8A8A.toInt(), grund)
        assertTrue(JoeWidgetColors.contrast(fix, grund) >= JoeWidgetColors.MIN_TEXT)
        assertTrue(JoeWidgetColors.luminance(fix) < JoeWidgetColors.luminance(grund))
    }
}
