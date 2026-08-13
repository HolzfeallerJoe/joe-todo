package dev.joe.joe_todo.widget

import android.content.Context
import android.graphics.Color
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Der Schnappschuss, den die App fuer die Widgets hinterlegt.
 *
 * Die Widgets laufen ohne Flutter – wenn das Telefon sie zeichnet, ist die
 * App fast immer tot. Sie rechnen deshalb nichts aus: kein
 * Wiederholungsmuster, keinen Feiertag, keine Sortierung. Hier steht nur,
 * was die App unter lib/home_widget.dart schon fertig gerechnet hat, Tag fuer
 * Tag. Das Widget sucht sich den Tag heraus, den die Uhr gerade zeigt.
 *
 * Gelesen wird streng defensiv: ein kaputter Eintrag darf hoechstens sich
 * selbst kosten. Eine Ausnahme aus onUpdate haette der Nutzer sonst als
 * "Widget kann nicht geladen werden" auf dem Startbildschirm stehen – und
 * kaeme da ohne Neuanlegen nicht wieder raus.
 */
class WidgetEntry(
    val title: String,
    val color: Int,
    val done: Boolean,
    /** Minute seit Mitternacht; -1 bei Aufgaben, die haben keine Uhrzeit. */
    val minute: Int,
    /**
     * Ob die Aufgabe an ihrem Tag faellig ist oder nur von frueher
     * mitgeschleppt wird. Auf dem Teller von heute liegt beides; der Blick
     * nach vorn zeigt nur, was dort wirklich neu ansteht – sonst stuende
     * jede heute offene Aufgabe auch morgen und uebermorgen da.
     */
    val carried: Boolean = false,
)

class WidgetDay(
    val tasks: List<WidgetEntry>,
    val taskCount: Int,
    /** Offene Aufgaben ohne Stufe 3 – gezaehlt wie im Dashboard. */
    val open: Int,
    val appointments: List<WidgetEntry>,
    val appointmentCount: Int,
    val note: Boolean,
    val holiday: String?,
    /**
     * Der Punkt im Monatsraster: die Farbe des ersten Eintrags, der an dem
     * Tag faellig ist, und ob alles davon erledigt ist (dann ein Ring).
     *
     * Kommt fertig aus dem Schnappschuss und nicht aus [tasks] – die Liste
     * traegt Liegengebliebenes weiter, sonst waere jeder kommende Tag
     * markiert, nur weil heute etwas offen ist.
     */
    val markerColor: Int?,
    val markerDone: Boolean,
) {
    companion object {
        val empty =
            WidgetDay(emptyList(), 0, 0, emptyList(), 0, false, null, null, false)
    }
}

class WidgetTheme(
    val paper: Int,
    val ink: Int,
    val inkSoft: Int,
    val accent: Int,
) {
    companion object {
        /** Das Design "Holz" – was die Widgets zeigen, solange die App noch
         *  nie geschoben hat. */
        val fallback = WidgetTheme(
            paper = 0xFFFAF3E3.toInt(),
            ink = 0xFF4A3527.toInt(),
            inkSoft = 0xFF7E6A59.toInt(),
            accent = 0xFFB35037.toInt(),
        )
    }
}

class WidgetSnapshot(
    private val from: String,
    private val to: String,
    val theme: WidgetTheme,
    private val days: Map<String, WidgetDay>,
    /** Kennzeichen dieses Datenstands. Daran erkennt ein Widget, ob sich
     *  seit dem letzten Zeichnen ueberhaupt etwas geaendert hat. */
    val stamp: Int,
) {
    /**
     * Ob ueber diesen Tag ueberhaupt etwas bekannt ist. Datumsschluessel sind
     * `JJJJ-MM-TT`, da faellt der Vergleich mit dem Zeichenketten-Vergleich
     * zusammen.
     */
    fun covers(key: String): Boolean = key >= from && key <= to

    /** Der Tag, oder ein leerer Tag – aber nur, wenn er im Zeitraum liegt. */
    fun day(key: String): WidgetDay? =
        if (!covers(key)) null else days[key] ?: WidgetDay.empty

    /** Nur die Tage, an denen wirklich etwas steht. */
    fun marked(key: String): WidgetDay? = days[key]
}

object JoeWidgetData {
    /** Muss zu widgetSnapshotVersion in lib/home_widget.dart passen. */
    private const val VERSION = 1
    private const val PREFS = "joe_widgets"
    private const val KEY = "snapshot"

    private var cachedRaw: String? = null
    private var cached: WidgetSnapshot? = null

    /**
     * Den Schnappschuss ablegen. Gibt zurueck, ob er sich ueberhaupt
     * geaendert hat.
     *
     * Die App schiebt bei jeder Aenderung, und beim Start schiebt sie
     * einmal ungefragt – meist steht danach genau dasselbe da wie vorher.
     * Dann darf auch kein Rundruf hinausgehen: jeder kostet vier
     * Widget-Zeichnungen im Prozess des Startbildschirms, und der hat
     * davon schon genug.
     */
    fun save(context: Context, json: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString(KEY, null) == json) return false
        prefs.edit().putString(KEY, json).apply()
        synchronized(this) {
            cachedRaw = null
            cached = null
        }
        return true
    }

    /**
     * Der zuletzt geschobene Stand, oder null, wenn es keinen gibt bzw. er
     * unlesbar ist. Vier Widgets werden nacheinander gezeichnet und lesen
     * denselben Text – deshalb wird das Ergebnis am Rohtext gemerkt.
     */
    fun load(context: Context): WidgetSnapshot? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return null
        synchronized(this) {
            if (raw == cachedRaw) return cached
        }
        val parsed = parse(raw)
        synchronized(this) {
            cachedRaw = raw
            cached = parsed
        }
        return parsed
    }

    private fun parse(raw: String): WidgetSnapshot? = try {
        val root = JSONObject(raw)
        if (root.optInt("version") != VERSION) {
            // Ein Schnappschuss aus einer anderen Fassung der App. Lieber der
            // Hinweis "Joe oeffnen" als geratene Felder.
            null
        } else {
            val days = HashMap<String, WidgetDay>()
            val raws = root.optJSONObject("days")
            if (raws != null) {
                for (key in raws.keys()) {
                    val entry = raws.optJSONObject(key) ?: continue
                    days[key] = parseDay(entry)
                }
            }
            WidgetSnapshot(
                from = root.optString("from"),
                to = root.optString("to"),
                theme = theme(root.optJSONObject("theme")),
                days = days,
                stamp = raw.hashCode(),
            )
        }
    } catch (e: Exception) {
        null
    }

    private fun parseDay(json: JSONObject): WidgetDay {
        val tasks = ArrayList<WidgetEntry>()
        val taskArray = json.optJSONArray("tasks")
        if (taskArray != null) {
            for (i in 0 until taskArray.length()) {
                val item = taskArray.optJSONObject(i) ?: continue
                tasks.add(
                    WidgetEntry(
                        title = item.optString("title"),
                        color = color(item.optString("color"), 0xFF888888.toInt()),
                        done = item.optBoolean("done"),
                        minute = -1,
                        carried = item.optBoolean("over"),
                    )
                )
            }
        }
        val appointments = ArrayList<WidgetEntry>()
        val appointmentArray = json.optJSONArray("appointments")
        if (appointmentArray != null) {
            for (i in 0 until appointmentArray.length()) {
                val item = appointmentArray.optJSONObject(i) ?: continue
                appointments.add(
                    WidgetEntry(
                        title = item.optString("title"),
                        color = color(item.optString("color"), 0xFF888888.toInt()),
                        done = false,
                        minute = item.optInt("minute", -1),
                    )
                )
            }
        }
        val holiday = json.optString("holiday", "")
        val mark = json.optJSONObject("mark")
        return WidgetDay(
            markerColor = if (mark == null) null else color(mark.optString("color"), 0xFF888888.toInt()),
            markerDone = mark?.optBoolean("done") == true,
            tasks = tasks,
            taskCount = json.optInt("taskCount", tasks.size),
            open = json.optInt("open", 0),
            appointments = appointments,
            appointmentCount = json.optInt("appointmentCount", appointments.size),
            note = json.optBoolean("note"),
            holiday = if (holiday.isEmpty()) null else holiday,
        )
    }

    private fun theme(json: JSONObject?): WidgetTheme {
        if (json == null) return WidgetTheme.fallback
        val fallback = WidgetTheme.fallback
        return WidgetTheme(
            paper = color(json.optString("paper"), fallback.paper),
            ink = color(json.optString("ink"), fallback.ink),
            inkSoft = color(json.optString("inkSoft"), fallback.inkSoft),
            accent = color(json.optString("accent"), fallback.accent),
        )
    }

    /** Farben stehen als `#AARRGGBB` im Schnappschuss – als Text, damit weder
     *  ein Vorzeichen noch ein Ueberlauf dazwischenkommt. */
    private fun color(value: String?, fallback: Int): Int = try {
        if (value.isNullOrEmpty()) fallback else Color.parseColor(value)
    } catch (e: IllegalArgumentException) {
        fallback
    }

    /** Der Datumsschluessel eines Tages, wie ihn lib/util.dart schreibt.
     *  Mit fester Locale: unter arabischen Ziffern waere "٢٠٢٦-٠٨-١٣" kein
     *  Schluessel mehr, der auf den Schnappschuss passt. */
    fun dayKey(cal: Calendar): String = String.format(
        Locale.ROOT,
        "%04d-%02d-%02d",
        cal.get(Calendar.YEAR),
        cal.get(Calendar.MONTH) + 1,
        cal.get(Calendar.DAY_OF_MONTH),
    )
}
