package dev.joe.joe_todo.widget

import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Kontrast fuer das Monatsraster.
 *
 * Die Punkte im Raster tragen nicht die Farben des Designs, sondern die der
 * Eintraege: ein Termin in hellem Gelb war auf dem hellen Papier kaum noch
 * zu sehen. Hier wird eine solche Farbe so weit zum Papier hin abgedunkelt
 * (oder auf dunklem Papier aufgehellt), bis sie den geforderten Kontrast
 * erreicht – gemischt wird dabei nur so viel wie noetig, damit der Farbton
 * erkennbar bleibt. Denselben Weg gehen die leisen Toene des Designs, wenn
 * ein Nutzerdesign sie zu blass gewaehlt hat.
 *
 * Reine Rechnerei ohne android.graphics, damit sie ohne Geraet testbar ist.
 */
internal object JoeWidgetColors {

    /** Was kleine Schrift braucht (WCAG AA). */
    const val MIN_TEXT = 4.5

    /** Was ein Punkt oder eine leise Beschriftung braucht (WCAG AA fuer
     *  Flaechen) – ein Marker muss auffindbar sein, nicht lesbar. */
    const val MIN_GLYPH = 3.0

    private const val WHITE = 0xFFFFFFFF.toInt()
    private const val BLACK = 0xFF000000.toInt()

    /** Relative Helligkeit nach WCAG, 0 (schwarz) bis 1 (weiss). */
    fun luminance(color: Int): Double {
        fun part(shift: Int): Double {
            val raw = ((color shr shift) and 0xFF) / 255.0
            return if (raw <= 0.04045) raw / 12.92 else ((raw + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * part(16) + 0.7152 * part(8) + 0.0722 * part(0)
    }

    /** Das Kontrastverhaeltnis zweier Farben, 1.0 bis 21.0. */
    fun contrast(a: Int, b: Int): Double {
        val first = luminance(a)
        val second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /**
     * [color] so weit veraendert, dass sie vor [background] den Kontrast
     * [minRatio] erreicht. Reicht die Farbe schon, bleibt sie, wie sie ist.
     */
    fun readable(color: Int, background: Int, minRatio: Double = MIN_TEXT): Int {
        if (contrast(color, background) >= minRatio) return color
        // Auf hellem Papier hilft nur Abdunkeln, auf dunklem nur Aufhellen –
        // und wo die Grenze liegt, sagt der Kontrast selbst. (Nach Gefuehl
        // bei halber Helligkeit zu trennen waere falsch: schon ein
        // mitteldunkles Grau traegt Schwarz besser als Weiss.)
        val target = if (contrast(BLACK, background) >= contrast(WHITE, background)) BLACK else WHITE
        // Mehr als den reinen Ton gibt der Grund nicht her; dann das Beste
        // nehmen, was es gibt, statt weiter zu mischen.
        if (contrast(target, background) < minRatio) return target
        // Der kleinste Mischanteil, der reicht: der Kontrast waechst mit dem
        // Anteil monoton, also findet ihn eine Intervallhalbierung.
        var enough = 1.0
        var tooLittle = 0.0
        repeat(10) {
            val mid = (tooLittle + enough) / 2
            if (contrast(mix(color, target, mid), background) >= minRatio) {
                enough = mid
            } else {
                tooLittle = mid
            }
        }
        return mix(color, target, enough)
    }

    /** [amount] Teile [target] auf [color] – die Deckkraft bleibt die der
     *  Ausgangsfarbe. */
    private fun mix(color: Int, target: Int, amount: Double): Int {
        fun channel(shift: Int): Int {
            val from = (color shr shift) and 0xFF
            val to = (target shr shift) and 0xFF
            return (from + (to - from) * amount).roundToInt().coerceIn(0, 255) shl shift
        }
        return (color and 0xFF000000.toInt()) or channel(16) or channel(8) or channel(0)
    }
}
