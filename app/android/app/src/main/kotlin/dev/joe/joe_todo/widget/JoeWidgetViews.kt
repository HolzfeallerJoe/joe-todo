package dev.joe.joe_todo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import dev.joe.joe_todo.R
import java.util.Calendar

/**
 * Wie die vier Widgets aussehen.
 *
 * Alles hier ist RemoteViews: das Widget lebt im Prozess des
 * Startbildschirms, nicht in Joe. Zeichnen heisst darum, dem fremden Prozess
 * eine Bauanleitung zu schicken – die Kalenderzellen kommen als
 * verschachtelte RemoteViews per addView dazu.
 *
 * Die Listen sind dagegen keine Bauanleitung, sondern eine Verbindung: der
 * Startbildschirm zeigt eine ListView und fragt beim Scrollen Zeile fuer
 * Zeile bei JoeWidgetListService nach. Was nicht hineinpasst, ist damit
 * nicht mehr weg, sondern nur noch nicht gescrollt.
 *
 * Die Farben kommen aus dem Schnappschuss, also aus dem Design, das in der
 * App gewaehlt ist. Der Hintergrund ist eine weiss gemalte Karte, die zur
 * Laufzeit eingefaerbt wird (SRC_ATOP laesst die runden Ecken durchsichtig).
 */
object JoeWidgetViews {

    /** Wenn es keinen Schnappschuss gibt: frisch installiert, oder die App
     *  war so lange nicht offen, dass der Zeitraum abgelaufen ist. Lieber
     *  ehrlich nichts zeigen als einen alten Stand von gestern. */
    private const val HINT = "Joe öffnen, dann steht hier, was ansteht."

    /** Hoehe einer Zeile bzw. einer Kalenderzeile in dp – so hoch sind die
     *  Layouts, und danach richtet sich, wie viel hineinpasst. */
    private const val ROW_DP = 20

    /** Was Titelzeile und Rand von der Hoehe wegnehmen. */
    private const val HEADER_DP = 30

    /** So hoch sind die drei Kalenderzellen, und ab so viel Platz pro Woche
     *  wird die naechstgroessere genommen. */
    private const val CELL_DP = 14
    private const val CELL_BIG_DP = 26
    private const val CELL_XL_DP = 36

    /** Das grosse Raster braucht auch Breite: Punkt und Notizkaestchen stehen
     *  dort nebeneinander unter der Zahl. In einem Widget, das nur zwei
     *  Felder breit ist, hat eine Spalte keine 20dp – dort bleibt es beim
     *  mittleren Raster, auch wenn die Hoehe fuer mehr reichen wuerde. */
    private const val CELL_XL_COLUMN_DP = 26

    // ---- Die vier Widgets ----

    fun tasks(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_tasks, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_TASKS),
        )
        views.setTextColor(R.id.joe_count, theme.inkSoft)

        val today = Calendar.getInstance()
        val day = snapshot?.day(JoeWidgetData.dayKey(today))
        views.setTextViewText(
            R.id.joe_count,
            when {
                day == null -> ""
                day.open == 0 -> "erledigt"
                else -> "${day.open} offen"
            },
        )
        // Die Liste traegt die Aufgaben von heute und danach den Blick nach
        // vorn; leer ist sie nur, wenn beides leer ist.
        bindList(
            context, views, widgetId, theme,
            R.id.joe_list, R.id.joe_empty,
            JoeWidgetList.KIND_TASKS, JoeWidgets.TARGET_TASKS,
            if (day == null) HINT else "Nichts für heute 🌿",
        )
        return views
    }

    fun appointments(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_appointments, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_APPOINTMENTS),
        )
        views.setTextColor(R.id.joe_count, theme.inkSoft)

        val today = Calendar.getInstance()
        views.setTextViewText(R.id.joe_count, JoeWidgetText.shortDate(today))
        val known = snapshot != null && snapshot.covers(JoeWidgetData.dayKey(today))
        bindList(
            context, views, widgetId, theme,
            R.id.joe_list, R.id.joe_empty,
            JoeWidgetList.KIND_APPOINTMENTS, JoeWidgets.TARGET_APPOINTMENTS,
            if (known) "Keine Termine in Sicht." else HINT,
        )
        return views
    }

    fun calendar(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_calendar, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_CALENDAR),
        )
        val today = Calendar.getInstance()
        views.setTextViewText(R.id.joe_title, JoeWidgetText.month(today))
        if (snapshot == null || !snapshot.covers(JoeWidgetData.dayKey(today))) {
            views.setViewVisibility(R.id.joe_grid, View.GONE)
            views.setViewVisibility(R.id.joe_empty, View.VISIBLE)
            views.setTextViewText(R.id.joe_empty, "Joe öffnen, dann stehen hier die Markierungen.")
            views.setTextColor(R.id.joe_empty, theme.inkSoft)
            return views
        }
        views.setViewVisibility(R.id.joe_grid, View.VISIBLE)
        views.setViewVisibility(R.id.joe_empty, View.GONE)
        // Was nach Titel, Wochentagszeile und Rand uebrig bleibt, teilen sich
        // die Wochen. Im 2x2 ist eine Zeile keine 14dp hoch: dort sagt die
        // eingefaerbte Flaeche, was ansteht. Groesser gezogen ist Platz fuer
        // den Punkt unter der Zahl wie in der App, und noch groesser fuer die
        // Notiz als gerahmtes "N".
        val free = height(context, options) - 18 - CELL_DP - 16
        val style = cellStyle(free / weeks(today), perColumn(context, options, 16))
        grid(context, views, R.id.joe_grid, theme, snapshot, today, style, stretch = true)
        return views
    }

    fun overview(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_overview, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_CALENDAR),
        )
        views.setOnClickPendingIntent(
            R.id.joe_tasks_column,
            JoeWidgets.open(context, JoeWidgets.TARGET_TASKS),
        )
        views.setOnClickPendingIntent(
            R.id.joe_appointments_column,
            JoeWidgets.open(context, JoeWidgets.TARGET_APPOINTMENTS),
        )
        views.setTextColor(R.id.joe_count, theme.inkSoft)
        views.setTextColor(R.id.joe_tasks_title, theme.ink)
        views.setTextColor(R.id.joe_appointments_title, theme.ink)
        views.setInt(R.id.joe_rule, "setBackgroundColor", fade(theme.inkSoft))
        views.setTextViewText(R.id.joe_tasks_title, "Heute")
        views.setTextViewText(R.id.joe_appointments_title, "Termine")

        val today = Calendar.getInstance()
        views.setTextViewText(R.id.joe_title, JoeWidgetText.month(today))

        val day = snapshot?.day(JoeWidgetData.dayKey(today))
        views.setTextViewText(
            R.id.joe_count,
            when {
                day == null -> ""
                day.open == 0 -> "erledigt"
                else -> "${day.open} offen"
            },
        )
        bindList(
            context, views, widgetId, theme,
            R.id.joe_list, R.id.joe_empty,
            JoeWidgetList.KIND_TASKS, JoeWidgets.TARGET_TASKS,
            if (day == null) "Joe öffnen" else "Nichts für heute 🌿",
        )
        bindList(
            context, views, widgetId, theme,
            R.id.joe_list_two, R.id.joe_empty_two,
            JoeWidgetList.KIND_APPOINTMENTS, JoeWidgets.TARGET_APPOINTMENTS,
            if (day == null) "Joe öffnen" else "Keine Termine in Sicht.",
        )
        if (snapshot == null || day == null) {
            grid(context, views, R.id.joe_grid, theme, null, today,
                cellStyle(0, 0), stretch = false)
            return views
        }

        // Das Raster nimmt sich, was es braucht, aber nie so viel, dass fuer
        // die beiden Listen darunter weniger als drei Zeilen bleiben – hier
        // wird es deshalb nicht gedehnt, sondern nur passend gross gewaehlt.
        // Drei Zeilen reichen als Rest, weil die Listen scrollen; was nicht
        // hineinpasst, ist nicht verloren.
        val weekCount = weeks(today)
        val free = height(context, options) - 30 - CELL_DP - 12
        val style = cellStyle(
            (free - 3 * ROW_DP) / weekCount,
            perColumn(context, options, 20),
        )
        grid(context, views, R.id.joe_grid, theme, snapshot, today, style, stretch = false)
        return views
    }

    // ---- Bausteine ----

    private fun card(context: Context, layout: Int, theme: WidgetTheme): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        views.setInt(R.id.joe_bg, "setColorFilter", theme.paper)
        views.setTextColor(R.id.joe_title, theme.ink)
        return views
    }

    /**
     * Eine Liste an ihren Nachschub haengen.
     *
     * Statt fertiger Zeilen bekommt der Startbildschirm eine Adresse: von da
     * holt er sich beim Scrollen, was er gerade braucht
     * (JoeWidgetListService). Was leer bleibt, sagt die Ansicht daneben – das
     * Umblenden macht der Startbildschirm selbst, sobald keine Zeile da ist.
     */
    @Suppress("DEPRECATION")
    private fun bindList(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        theme: WidgetTheme,
        listId: Int,
        emptyId: Int,
        kind: String,
        target: String,
        emptyText: String,
    ) {
        views.setRemoteAdapter(listId, JoeWidgetList.intent(context, widgetId, kind))
        views.setEmptyView(listId, emptyId)
        views.setTextViewText(emptyId, emptyText)
        views.setTextColor(emptyId, theme.inkSoft)
        // Eine angetippte Zeile faellt nicht an die Karte durch – eine Liste
        // faengt die Beruehrung selbst ab. Ohne Vorlage waeren die Zeilen
        // tot; mit ihr fuehren sie dorthin, wohin auch die Karte fuehrt.
        views.setPendingIntentTemplate(listId, JoeWidgets.openTemplate(context, target))
    }

    /**
     * Eine fertige Zeile – das, was der Nachschub-Dienst beim Scrollen
     * zurueckgibt.
     */
    internal fun line(
        context: Context,
        theme: WidgetTheme,
        style: RowStyle,
        line: WidgetLine,
    ): RemoteViews {
        val views = when (line.kind) {
            WidgetLine.Kind.HEAD -> head(context, theme, style, line.title)
            WidgetLine.Kind.MUTED -> muted(context, theme, style, line.title)
            WidgetLine.Kind.ENTRY ->
                row(context, theme, style, line.title, line.lead, line.color, line.done)
        }
        // Die Vorlage der Liste traegt schon alles; die Zeile muss nur sagen,
        // dass sie ueberhaupt angetippt werden kann.
        views.setOnClickFillInIntent(
            if (line.kind == WidgetLine.Kind.HEAD) R.id.joe_head_title else R.id.joe_row_root,
            Intent(),
        )
        return views
    }

    private fun row(
        context: Context,
        theme: WidgetTheme,
        style: RowStyle,
        title: String,
        lead: String?,
        color: Int,
        done: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.joe_widget_row)
        // Ring statt Punkt fuer erledigt – dieselbe Sprache wie im Kalender
        // der App.
        views.setImageViewResource(
            R.id.joe_row_dot,
            if (done) R.drawable.joe_widget_ring else R.drawable.joe_widget_dot,
        )
        views.setInt(R.id.joe_row_dot, "setColorFilter", color)
        views.setTextViewText(R.id.joe_row_title, title)
        views.setTextColor(R.id.joe_row_title, if (done) theme.inkSoft else theme.ink)
        views.setTextViewTextSize(
            R.id.joe_row_title, TypedValue.COMPLEX_UNIT_SP, style.titleSp)
        if (lead == null) {
            views.setViewVisibility(R.id.joe_row_lead, View.GONE)
        } else {
            views.setViewVisibility(R.id.joe_row_lead, View.VISIBLE)
            views.setTextViewText(R.id.joe_row_lead, lead)
            views.setTextColor(R.id.joe_row_lead, theme.inkSoft)
            views.setTextViewTextSize(
                R.id.joe_row_lead, TypedValue.COMPLEX_UNIT_SP, style.leadSp)
        }
        return views
    }

    private fun head(
        context: Context,
        theme: WidgetTheme,
        style: RowStyle,
        title: String,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.joe_widget_head)
        views.setTextViewText(R.id.joe_head_title, title)
        views.setTextColor(R.id.joe_head_title, theme.accent)
        views.setTextViewTextSize(
            R.id.joe_head_title, TypedValue.COMPLEX_UNIT_SP, style.headSp)
        return views
    }

    /** Eine Zeile ohne Punkt, in leiser Farbe – fuer "+3 weitere" und fuer
     *  den leeren Tag in den schmalen Spalten des grossen Widgets. */
    private fun muted(
        context: Context,
        theme: WidgetTheme,
        style: RowStyle,
        text: String,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.joe_widget_row)
        views.setViewVisibility(R.id.joe_row_dot, View.INVISIBLE)
        views.setViewVisibility(R.id.joe_row_lead, View.GONE)
        views.setTextViewText(R.id.joe_row_title, text)
        views.setTextColor(R.id.joe_row_title, theme.inkSoft)
        views.setTextViewTextSize(
            R.id.joe_row_title, TypedValue.COMPLEX_UNIT_SP, style.titleSp)
        return views
    }

    // ---- Monatsraster ----

    /**
     * Wie gross die Zellen eines Rasters ausfallen. Drei Stufen, ausgesucht
     * nach dem Platz, den eine Woche bekommt: Wer das Widget in die Laenge
     * zieht, soll nicht dieselben Miniaturzahlen mit viel Luft darum sehen.
     *
     * Alle drei sind gebaut wie die Zelle im Kalender der App: Zahl in
     * Tinte, heute ein Rahmen um die Zelle.
     *
     * [dots] sagt, wie der Eintrag am Tag steht: als Punkt unter der Zahl wie
     * in der App – oder, wenn dafuer kein Platz ist, als leichte Einfaerbung
     * der ganzen Zelle. [letter] sagt, ob die Notiz das gerahmte "N" der App
     * traegt; dafuer braucht es Platz, den nur das grosse Raster hat, die
     * kleineren zeigen nur das Kaestchen.
     */
    private class CellStyle(
        val layout: Int,
        val dots: Boolean,
        val letter: Boolean,
        val daySp: Float,
        val labelSp: Float,
        /** So hoch ist die Zelle von sich aus – gebraucht dort, wo das Raster
         *  nicht gedehnt wird und man wissen muss, was es wegnimmt. */
        val heightDp: Int,
    )

    /**
     * Die Zelle zur vorhandenen Flaeche – es zaehlen beide Richtungen.
     *
     * Die Hoehe entscheidet, was unter die Zahl passt: der Punkt, der Punkt
     * mit Notizkaestchen, oder nichts (dann faerbt der Eintrag die Flaeche).
     * Die Zahl richtet sich nach der knapperen der beiden Richtungen – ein
     * Widget, das nur zwei Felder breit, aber vier hoch ist, hat viel Hoehe
     * und trotzdem keine 20dp pro Spalte, und grosse Zahlen stuenden dort
     * Schulter an Schulter.
     */
    private fun cellStyle(perWeekDp: Int, perColumnDp: Int): CellStyle {
        val room = minOf(perWeekDp, perColumnDp)
        val wanted = when {
            room >= 26 -> 15f
            room >= 20 -> 13f
            room >= 15 -> 11f
            else -> 9f
        }
        return when {
            perWeekDp >= CELL_XL_DP && perColumnDp >= CELL_XL_COLUMN_DP ->
                cell(R.layout.joe_widget_cal_cell_xl, true, true, wanted, 15f, CELL_XL_DP)
            perWeekDp >= CELL_BIG_DP ->
                cell(R.layout.joe_widget_cal_cell_big, true, false, wanted, 13f, CELL_BIG_DP)
            else ->
                cell(R.layout.joe_widget_cal_cell, false, false, wanted, 11f, CELL_DP)
        }
    }

    /** [cap] ist, was das Layout traegt: die Zahl sitzt dort in einem Kasten
     *  fester Groesse und darf nicht groesser werden als der. */
    private fun cell(
        layout: Int,
        dots: Boolean,
        letter: Boolean,
        wantedSp: Float,
        cap: Float,
        heightDp: Int,
    ): CellStyle {
        val daySp = minOf(wantedSp, cap)
        // Die Wochentage stehen eine Spur kleiner als die Zahlen, wie in der
        // App (13 zu 12).
        return CellStyle(layout, dots, letter, daySp, minOf(daySp - 1f, 12f), heightDp)
    }

    /**
     * Das Monatsraster.
     *
     * [stretch] entscheidet, ob die Wochen sich die vorhandene Hoehe teilen
     * (Kalender-Widget: es fuellt, in welche Groesse man es auch zieht) oder
     * nur so hoch werden, wie sie brauchen (Uebersicht: darunter stehen noch
     * die beiden Listen).
     */
    private fun grid(
        context: Context,
        views: RemoteViews,
        container: Int,
        theme: WidgetTheme,
        snapshot: WidgetSnapshot?,
        today: Calendar,
        style: CellStyle,
        stretch: Boolean,
    ) {
        views.removeAllViews(container)

        val header = RemoteViews(context.packageName, R.layout.joe_widget_cal_row_wrap)
        for (name in JoeWidgetText.WEEKDAYS) {
            val cell = RemoteViews(context.packageName, R.layout.joe_widget_cal_head_cell)
            cell.setTextViewText(R.id.joe_cell_day, name)
            // Leise, aber nicht blass: "Mo" bis "So" stehen so klein da, dass
            // ein zu heller Ton auf dem Papier verschwindet.
            cell.setTextColor(
                R.id.joe_cell_day,
                JoeWidgetColors.readable(theme.inkSoft, theme.paper, JoeWidgetColors.MIN_GLYPH),
            )
            cell.setTextViewTextSize(R.id.joe_cell_day, TypedValue.COMPLEX_UNIT_SP, style.labelSp)
            header.addView(R.id.joe_cal_row, cell)
        }
        views.addView(container, header)

        val rowLayout =
            if (stretch) R.layout.joe_widget_cal_row else R.layout.joe_widget_cal_row_wrap
        val cursor = today.clone() as Calendar
        cursor.set(Calendar.DAY_OF_MONTH, 1)
        val offset = JoeWidgetText.mondayFirst(cursor)
        val length = cursor.getActualMaximum(Calendar.DAY_OF_MONTH)
        val todayKey = JoeWidgetData.dayKey(today)

        var slot = 0
        while (slot < offset + length) {
            val week = RemoteViews(context.packageName, rowLayout)
            for (column in 0 until 7) {
                val cell = RemoteViews(context.packageName, style.layout)
                val number = slot - offset + 1
                if (number < 1 || number > length) {
                    // Ein Feld vor dem Ersten oder nach dem Letzten bleibt
                    // leer; Kreis, Punkt und Notizzeichen sind im Layout
                    // ohnehin schon weg.
                    cell.setTextViewText(R.id.joe_cell_day, "")
                } else {
                    cursor.set(Calendar.DAY_OF_MONTH, number)
                    fill(cell, theme, snapshot?.marked(JoeWidgetData.dayKey(cursor)), number,
                        isToday = JoeWidgetData.dayKey(cursor) == todayKey, style = style)
                }
                week.addView(R.id.joe_cal_row, cell)
                slot++
            }
            views.addView(container, week)
        }
    }

    private fun fill(
        cell: RemoteViews,
        theme: WidgetTheme,
        day: WidgetDay?,
        number: Int,
        isToday: Boolean,
        style: CellStyle,
    ) {
        cell.setTextViewText(R.id.joe_cell_day, number.toString())
        cell.setTextViewTextSize(R.id.joe_cell_day, TypedValue.COMPLEX_UNIT_SP, style.daySp)
        val accent = JoeWidgetColors.readable(theme.accent, theme.paper)

        // Die Zahl steht wie in der App immer in Tinte – nur heute traegt sie
        // den Akzent, und ein Feiertag auch: dafuer hat die App den Stern in
        // der Badge-Zeile, und ohne den bleibt die Farbe der einzige Hinweis.
        cell.setTextColor(
            R.id.joe_cell_day,
            when {
                isToday -> accent
                day?.holiday != null -> accent
                else -> theme.ink
            },
        )

        // Heute: ein Rahmen um die Zelle statt einer gefuellten Flaeche, wie
        // im Kalender der App. So bleibt darin alles so gefaerbt wie an jedem
        // anderen Tag.
        if (isToday) {
            cell.setViewVisibility(R.id.joe_cell_today, View.VISIBLE)
            cell.setInt(R.id.joe_cell_today, "setColorFilter", accent)
        } else {
            cell.setViewVisibility(R.id.joe_cell_today, View.GONE)
        }

        // Was am Tag ansteht: im grossen Raster der Punkt unter der Zahl wie
        // in der App, gefuellt fuer offen und als Ring fuer erledigt. Im
        // kleinen ist dafuer kein Platz – dort traegt die Flaeche die Farbe,
        // kraeftig fuer offen und leiser fuer erledigt.
        //
        // Beide Male darf die Farbe des Eintrags nicht blass auf blassem
        // Papier liegen: eine Markierung muss auffindbar sein (aber nicht
        // lesbar, sie darf also heller bleiben als eine Zahl).
        val mark = if (style.dots) R.id.joe_cell_dot else R.id.joe_cell_fill
        val marker = day?.markerColor
        if (day == null || marker == null) {
            cell.setViewVisibility(mark, View.GONE)
        } else {
            cell.setViewVisibility(mark, View.VISIBLE)
            cell.setImageViewResource(
                mark,
                if (style.dots) {
                    if (day.markerDone) R.drawable.joe_widget_ring
                    else R.drawable.joe_widget_dot
                } else {
                    if (day.markerDone) R.drawable.joe_widget_cell_fill_soft
                    else R.drawable.joe_widget_cell_fill
                },
            )
            cell.setInt(
                mark,
                "setColorFilter",
                JoeWidgetColors.readable(marker, theme.paper, JoeWidgetColors.MIN_GLYPH),
            )
        }

        if (day?.note == true) {
            cell.setViewVisibility(R.id.joe_cell_note, View.VISIBLE)
            // Im grossen Raster ist die Notiz das gerahmte "N" der App: der
            // Rahmen ist ein Bild und wird eingefaerbt, der Buchstabe liegt
            // als eigene Ansicht darin. Die kleineren Raster haben nur das
            // Kaestchen, und das ist selbst das Bild.
            if (style.letter) {
                cell.setInt(R.id.joe_cell_note_box, "setColorFilter", accent)
                cell.setTextColor(R.id.joe_cell_note_letter, accent)
            } else {
                cell.setInt(R.id.joe_cell_note, "setColorFilter", accent)
            }
        } else {
            cell.setViewVisibility(R.id.joe_cell_note, View.GONE)
        }
    }

    // ---- Rechnerei ----

    private fun weeks(today: Calendar): Int {
        val first = today.clone() as Calendar
        first.set(Calendar.DAY_OF_MONTH, 1)
        val slots =
            JoeWidgetText.mondayFirst(first) + first.getActualMaximum(Calendar.DAY_OF_MONTH)
        return (slots + 6) / 7
    }

    /**
     * Die Hoehe des Widgets in dp.
     *
     * Der Startbildschirm meldet nicht die Hoehe von jetzt, sondern die
     * Spanne ueber beide Lagen: hochkant ist das Widget schmal und hoch,
     * quer breit und flach. MIN_HEIGHT ist damit die Hoehe im *Querformat* –
     * wer sie hochkant nimmt, rechnet mit der halben Karte und laesst die
     * untere Haelfte leer. Ohne Angabe (der Startbildschirm gibt das Buendel
     * leer) wird mit 2x2 gerechnet: lieber zu wenig Zeilen als
     * abgeschnittene.
     */
    private fun height(context: Context, options: Bundle): Int {
        val portrait = context.resources.configuration.orientation !=
            Configuration.ORIENTATION_LANDSCAPE
        val value = options.getInt(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
            0,
        )
        return if (value > 0) value else 110
    }

    /**
     * Die Breite des Widgets in dp – dieselbe Rechnung wie bei der Hoehe, nur
     * andersherum: hochkant ist das Widget schmal, also steht die Breite von
     * jetzt in MIN_WIDTH, quer in MAX_WIDTH.
     */
    private fun width(context: Context, options: Bundle): Int {
        val portrait = context.resources.configuration.orientation !=
            Configuration.ORIENTATION_LANDSCAPE
        val value = options.getInt(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
            else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,
            0,
        )
        return if (value > 0) value else 110
    }

    /** Was eine Spalte des Monatsrasters an Breite bekommt. */
    private fun perColumn(context: Context, options: Bundle, paddingDp: Int): Int =
        ((width(context, options) - paddingDp) / 7).coerceAtLeast(1)

    /**
     * Wie gross eine Listenzeile ausfaellt.
     *
     * Zwei Stufen, ausgesucht nach dem Platz, den die Liste bekommt. Wer ein
     * Widget in die Laenge zieht, will nicht dieselbe Miniaturschrift in
     * einer grossen Karte sehen.
     */
    internal class RowStyle(
        val heightDp: Int,
        val titleSp: Float,
        val leadSp: Float,
        val headSp: Float,
    )

    private fun rowStyle(listAreaDp: Int): RowStyle =
        if (listAreaDp >= 200) RowStyle(26, 14f, 13f, 12f)
        else RowStyle(ROW_DP, 12f, 11f, 11f)

    /**
     * Dasselbe fuer den Nachschub-Dienst: der kennt nur die Nummer des
     * Widgets und muss sich dessen Groesse selbst holen. Ohne Nummer (oder
     * ohne Auskunft) gilt das kleine Mass – lieber zu klein als
     * abgeschnitten.
     */
    internal fun rowStyleFor(context: Context, widgetId: Int): RowStyle {
        val options = if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Bundle.EMPTY
        } else {
            AppWidgetManager.getInstance(context)?.getAppWidgetOptions(widgetId) ?: Bundle.EMPTY
        }
        return rowStyle(height(context, options) - HEADER_DP)
    }

    /** Dieselbe Farbe, nur leise – fuer die Trennlinie im grossen Widget. */
    private fun fade(color: Int): Int = (color and 0x00FFFFFF) or 0x33000000
}
