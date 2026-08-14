package dev.joe.joe_todo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
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
 * eine Bauanleitung zu schicken – Zeilen und Kalenderzellen kommen als
 * verschachtelte RemoteViews per addView dazu. Eine Liste zum Scrollen waere
 * ein RemoteViewsService mit eigenem Adapter; dafuer ist in 2x2 kein Platz,
 * und was nicht mehr hineinpasst, sagt die letzte Zeile als "+3 weitere".
 *
 * Die Farben kommen aus dem Schnappschuss, also aus dem Design, das in der
 * App gewaehlt ist. Der Hintergrund ist eine weiss gemalte Karte, die zur
 * Laufzeit eingefaerbt wird (SRC_ATOP laesst die runden Ecken durchsichtig).
 */
object JoeWidgetViews {

    // Deutsch, wie ueberall in Joe (lib/util.dart) – und ohne Locale-Gerate:
    // ein Telefon auf Englisch soll im Widget nicht ploetzlich "Mon" sagen,
    // waehrend die App daneben "Mo" schreibt.
    private val WEEKDAYS = arrayOf("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So")
    private val MONTHS = arrayOf(
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    )
    private val MONTHS_SHORT = arrayOf(
        "Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
        "Jul", "Aug", "Sep", "Okt", "Nov", "Dez",
    )

    /** Hoehe einer Zeile bzw. einer Kalenderzeile in dp – so hoch sind die
     *  Layouts, und danach richtet sich, wie viel hineinpasst. */
    private const val ROW_DP = 20

    /** Was Titelzeile und Rand von der Hoehe wegnehmen. */
    private const val HEADER_DP = 30

    /** Wie weit der Blick nach vorn hoechstens sucht. Der Schnappschuss
     *  endet ohnehin frueher; das hier ist nur die Bremse. */
    private const val AHEAD_DAYS = 60
    private const val CELL_DP = 14
    private const val CELL_BIG_DP = 25
    private const val CELL_XL_DP = 32

    // ---- Die vier Widgets ----

    fun tasks(context: Context, options: Bundle, snapshot: WidgetSnapshot?): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_tasks, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_TASKS),
        )
        views.setTextColor(R.id.joe_count, theme.inkSoft)

        val today = Calendar.getInstance()
        val day = snapshot?.day(JoeWidgetData.dayKey(today))
        if (snapshot == null || day == null) {
            hint(views, theme)
            return views
        }
        views.setTextViewText(
            R.id.joe_count,
            if (day.open == 0) "erledigt" else "${day.open} offen",
        )
        val style = rowStyle(height(context, options) - HEADER_DP)
        val max = rowCount(context, options, style)
        val used = if (day.tasks.isEmpty()) {
            note(context, views, R.id.joe_list, theme, style, "Nichts für heute 🌿")
            1
        } else {
            list(context, views, R.id.joe_list, theme, style, day.tasks,
                day.taskCount, max) { entry ->
                row(context, theme, style, entry.title, null, entry.color, entry.done)
            }
        }
        // Was danach noch an Platz bleibt, fuellt der Blick nach vorn.
        ahead(context, views, R.id.joe_list, theme, style, snapshot, today, max - used)
        return views
    }

    fun appointments(context: Context, options: Bundle, snapshot: WidgetSnapshot?): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_appointments, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_APPOINTMENTS),
        )
        views.setTextColor(R.id.joe_count, theme.inkSoft)

        val today = Calendar.getInstance()
        views.setTextViewText(R.id.joe_count, shortDate(today))
        if (snapshot == null || !snapshot.covers(JoeWidgetData.dayKey(today))) {
            hint(views, theme)
            return views
        }
        val style = rowStyle(height(context, options) - HEADER_DP)
        val max = rowCount(context, options, style)
        val added =
            upcoming(context, views, R.id.joe_list, theme, style, snapshot, today, max)
        if (added == 0) empty(views, theme, "Keine Termine in Sicht.")
        return views
    }

    fun calendar(context: Context, options: Bundle, snapshot: WidgetSnapshot?): RemoteViews {
        val theme = snapshot?.theme ?: WidgetTheme.fallback
        val views = card(context, R.layout.joe_widget_calendar, theme)
        views.setOnClickPendingIntent(
            R.id.joe_root,
            JoeWidgets.open(context, JoeWidgets.TARGET_CALENDAR),
        )
        val today = Calendar.getInstance()
        views.setTextViewText(
            R.id.joe_title,
            "${MONTHS[today.get(Calendar.MONTH)]} ${today.get(Calendar.YEAR)}",
        )
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
        // die Wochen. Groesser gezogen wachsen die Zellen mit und bekommen
        // den Punkt unter der Zahl; im 2x2 traegt die Zahl die Farbe selbst,
        // dort ist fuer beides kein Platz.
        val free = height(context, options) - 18 - CELL_DP - 16
        val style = cellStyle(free / weeks(today))
        grid(context, views, R.id.joe_grid, theme, snapshot, today, style, stretch = true)
        return views
    }

    fun overview(context: Context, options: Bundle, snapshot: WidgetSnapshot?): RemoteViews {
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
        views.setTextViewText(
            R.id.joe_title,
            "${MONTHS[today.get(Calendar.MONTH)]} ${today.get(Calendar.YEAR)}",
        )

        val day = snapshot?.day(JoeWidgetData.dayKey(today))
        if (snapshot == null || day == null) {
            views.setTextViewText(R.id.joe_count, "")
            grid(context, views, R.id.joe_grid, theme, null, today,
                cellStyle(0), stretch = false)
            note(context, views, R.id.joe_list, theme, rowStyle(0), "Joe öffnen")
            note(context, views, R.id.joe_list_two, theme, rowStyle(0), "Joe öffnen")
            return views
        }
        views.setTextViewText(
            R.id.joe_count,
            if (day.open == 0) "erledigt" else "${day.open} offen",
        )

        // Das Raster nimmt sich, was es braucht, aber nie so viel, dass fuer
        // die beiden Listen darunter weniger als fuenf Zeilen bleiben – hier
        // wird es deshalb nicht gedehnt, sondern nur passend gross gewaehlt.
        val weekCount = weeks(today)
        val free = height(context, options) - 30 - CELL_DP - 12
        val style = cellStyle((free - 5 * ROW_DP) / weekCount)
        grid(context, views, R.id.joe_grid, theme, snapshot, today, style, stretch = false)

        val forLists = free - weekCount * style.heightDp - 16
        val rows = rowStyle(forLists)
        val max = (forLists / rows.heightDp).coerceIn(1, 12)
        val used = if (day.tasks.isEmpty()) {
            note(context, views, R.id.joe_list, theme, rows, "Nichts für heute 🌿")
            1
        } else {
            list(context, views, R.id.joe_list, theme, rows, day.tasks, day.taskCount,
                max) { entry ->
                row(context, theme, rows, entry.title, null, entry.color, entry.done)
            }
        }
        ahead(context, views, R.id.joe_list, theme, rows, snapshot, today, max - used)
        if (upcoming(context, views, R.id.joe_list_two, theme, rows, snapshot, today,
                max) == 0) {
            note(context, views, R.id.joe_list_two, theme, rows, "Keine Termine in Sicht.")
        }
        return views
    }

    // ---- Bausteine ----

    private fun card(context: Context, layout: Int, theme: WidgetTheme): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        views.setInt(R.id.joe_bg, "setColorFilter", theme.paper)
        views.setTextColor(R.id.joe_title, theme.ink)
        return views
    }

    /** Die Zeilen einer Liste, mit "+n weitere" als letzter Zeile, wenn nicht
     *  alles hineinpasst. */
    private fun <T> list(
        context: Context,
        views: RemoteViews,
        container: Int,
        theme: WidgetTheme,
        style: RowStyle,
        entries: List<T>,
        total: Int,
        max: Int,
        build: (T) -> RemoteViews,
    ): Int {
        views.removeAllViews(container)
        // Passt nicht alles, kostet der Hinweis selbst eine Zeile.
        val room = if (total > max) max - 1 else max
        val shown = entries.take(room.coerceAtLeast(0))
        for (entry in shown) views.addView(container, build(entry))
        val rest = total - shown.size
        if (rest == 0) return shown.size
        views.addView(
            container,
            muted(context, theme, style,
                if (rest == 1) "+1 weiterer" else "+$rest weitere"),
        )
        return shown.size + 1
    }

    /**
     * Was in den naechsten Tagen ansteht, nach Tagen gruppiert – der Rest
     * eines langen Widgets, unter dem, was heute dran ist.
     *
     * Gezeigt wird nur, was an dem Tag wirklich neu faellig ist: die
     * Tagesliste im Schnappschuss traegt Liegengebliebenes mit (so steht es
     * auch im Dashboard), und ohne diesen Filter stuende jede heute offene
     * Aufgabe hier an jedem einzelnen kommenden Tag noch einmal.
     */
    private fun ahead(
        context: Context,
        views: RemoteViews,
        container: Int,
        theme: WidgetTheme,
        style: RowStyle,
        snapshot: WidgetSnapshot,
        today: Calendar,
        max: Int,
    ) {
        if (max <= 0) return
        val cursor = today.clone() as Calendar
        cursor.add(Calendar.DAY_OF_MONTH, 1)
        var used = 0
        var days = 0
        while (used < max && days < AHEAD_DAYS) {
            val key = JoeWidgetData.dayKey(cursor)
            if (!snapshot.covers(key)) break
            val due = snapshot.marked(key)?.tasks?.filter { !it.carried }.orEmpty()
            // Die Ueberschrift lohnt nur, wenn unter ihr auch etwas steht.
            if (due.isNotEmpty() && used + 1 < max) {
                views.addView(
                    container, head(context, theme, style, relativeDay(cursor, today)))
                used++
                for (entry in due) {
                    if (used >= max) break
                    views.addView(
                        container,
                        row(context, theme, style, entry.title, null, entry.color,
                            entry.done),
                    )
                    used++
                }
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1)
            days++
        }
    }

    /**
     * Die naechsten Termine ab [today], nach Tagen gruppiert. Gibt zurueck,
     * wie viele Termine wirklich gezeigt wurden.
     *
     * Die Uhrzeit steht in der Zeile, das Datum in der Ueberschrift darueber –
     * in einem 2x2 waere fuer beides in einer Zeile kein Platz.
     */
    private fun upcoming(
        context: Context,
        views: RemoteViews,
        container: Int,
        theme: WidgetTheme,
        style: RowStyle,
        snapshot: WidgetSnapshot,
        today: Calendar,
        max: Int,
    ): Int {
        views.removeAllViews(container)
        val cursor = today.clone() as Calendar
        var used = 0
        var shown = 0
        var days = 0
        while (used < max && days < 400) {
            val key = JoeWidgetData.dayKey(cursor)
            if (!snapshot.covers(key)) break
            val day = snapshot.marked(key)
            if (day != null && day.appointments.isNotEmpty() &&
                JoeWidgetLayoutLogic.canStartGroup(used, max)) {
                views.addView(
                    container, head(context, theme, style, relativeDay(cursor, today)))
                used++
                val available = max - used
                val total = maxOf(day.appointmentCount, day.appointments.size)
                val plan = JoeWidgetLayoutLogic.appointments(
                    total = total,
                    loaded = day.appointments.size,
                    available = available,
                )
                if (plan.summaryOnly) {
                    views.addView(
                        container,
                        muted(context, theme, style,
                            if (total == 1) "1 Termin" else "$total Termine"),
                    )
                    used++
                    shown++
                    break
                }

                val entries = day.appointments.take(plan.entries)
                for (entry in entries) {
                    views.addView(
                        container,
                        row(context, theme, style, entry.title, time(entry.minute),
                            entry.color, false),
                    )
                    used++
                    shown++
                }
                val remaining = plan.hidden
                if (remaining > 0 && used < max) {
                    views.addView(
                        container,
                        muted(
                            context,
                            theme,
                            style,
                            if (remaining == 1) "+1 weiterer Termin"
                            else "+$remaining weitere Termine",
                        ),
                    )
                    used++
                    shown++
                    break
                }
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1)
            days++
        }
        return shown
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

    private fun note(
        context: Context,
        views: RemoteViews,
        container: Int,
        theme: WidgetTheme,
        style: RowStyle,
        text: String,
    ) {
        views.removeAllViews(container)
        views.addView(container, muted(context, theme, style, text))
    }

    private fun empty(views: RemoteViews, theme: WidgetTheme, text: String) {
        views.removeAllViews(R.id.joe_list)
        views.setViewVisibility(R.id.joe_empty, View.VISIBLE)
        views.setTextViewText(R.id.joe_empty, text)
        views.setTextColor(R.id.joe_empty, theme.inkSoft)
    }

    /** Wenn es keinen Schnappschuss gibt: frisch installiert, oder die App
     *  war so lange nicht offen, dass der Zeitraum abgelaufen ist. Lieber
     *  ehrlich nichts zeigen als einen alten Stand von gestern. */
    private fun hint(views: RemoteViews, theme: WidgetTheme) {
        empty(views, theme, "Joe öffnen, dann steht hier, was ansteht.")
    }

    // ---- Monatsraster ----

    /**
     * Wie gross die Zellen eines Rasters ausfallen. Drei Stufen, ausgesucht
     * nach dem Platz, den eine Woche bekommt: Wer das Widget in die Laenge
     * zieht, soll nicht dieselben Miniaturzahlen mit viel Luft darum sehen.
     *
     * [dots] sagt, ob die Zelle den Punkt unter der Zahl hat. Die kleinste
     * hat ihn nicht – dort traegt die Zahl selbst die Farbe des Eintrags.
     */
    private class CellStyle(
        val layout: Int,
        val dots: Boolean,
        val labelSp: Float,
        /** So hoch ist die Zelle von sich aus – gebraucht dort, wo das Raster
         *  nicht gedehnt wird und man wissen muss, was es wegnimmt. */
        val heightDp: Int,
    )

    private fun cellStyle(perWeekDp: Int): CellStyle = when {
        perWeekDp >= CELL_XL_DP ->
            CellStyle(R.layout.joe_widget_cal_cell_xl, true, 12f, CELL_XL_DP)
        perWeekDp >= CELL_BIG_DP ->
            CellStyle(R.layout.joe_widget_cal_cell_big, true, 11f, CELL_BIG_DP)
        else ->
            CellStyle(R.layout.joe_widget_cal_cell, false, 11f, CELL_DP)
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
        for (name in WEEKDAYS) {
            val cell = RemoteViews(context.packageName, R.layout.joe_widget_cal_head_cell)
            cell.setTextViewText(R.id.joe_cell_day, name)
            cell.setTextColor(R.id.joe_cell_day, theme.inkSoft)
            cell.setTextViewTextSize(R.id.joe_cell_day, TypedValue.COMPLEX_UNIT_SP, style.labelSp)
            header.addView(R.id.joe_cal_row, cell)
        }
        views.addView(container, header)

        val rowLayout =
            if (stretch) R.layout.joe_widget_cal_row else R.layout.joe_widget_cal_row_wrap
        val cursor = today.clone() as Calendar
        cursor.set(Calendar.DAY_OF_MONTH, 1)
        val offset = mondayFirst(cursor)
        val length = cursor.getActualMaximum(Calendar.DAY_OF_MONTH)
        val todayKey = JoeWidgetData.dayKey(today)

        var slot = 0
        while (slot < offset + length) {
            val week = RemoteViews(context.packageName, rowLayout)
            for (column in 0 until 7) {
                val cell = RemoteViews(context.packageName, style.layout)
                val number = slot - offset + 1
                if (number < 1 || number > length) {
                    cell.setTextViewText(R.id.joe_cell_day, "")
                    cell.setViewVisibility(R.id.joe_cell_note, View.INVISIBLE)
                    if (style.dots) cell.setViewVisibility(R.id.joe_cell_dot, View.INVISIBLE)
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
        val big = style.dots
        cell.setTextViewText(R.id.joe_cell_day, number.toString())
        cell.setViewVisibility(
            R.id.joe_cell_note,
            if (day?.note == true) View.VISIBLE else View.INVISIBLE,
        )
        cell.setTextColor(R.id.joe_cell_note, theme.accent)
        val marker = day?.markerColor
        if (isToday) {
            cell.setViewVisibility(R.id.joe_cell_today, View.VISIBLE)
            cell.setInt(R.id.joe_cell_today, "setColorFilter", theme.accent)
            cell.setTextColor(R.id.joe_cell_day, theme.paper)
        } else {
            cell.setViewVisibility(R.id.joe_cell_today, View.GONE)
            cell.setTextColor(
                R.id.joe_cell_day,
                when {
                    // Im kleinen Raster traegt die Zahl selbst die Farbe des
                    // Eintrags, im grossen der Punkt darunter.
                    !big && marker != null -> marker
                    day?.holiday != null -> theme.accent
                    else -> theme.ink
                },
            )
        }
        if (big) {
            if (day == null || marker == null) {
                cell.setViewVisibility(R.id.joe_cell_dot, View.INVISIBLE)
            } else {
                cell.setViewVisibility(R.id.joe_cell_dot, View.VISIBLE)
                cell.setImageViewResource(
                    R.id.joe_cell_dot,
                    if (day.markerDone) R.drawable.joe_widget_ring else R.drawable.joe_widget_dot,
                )
                cell.setInt(R.id.joe_cell_dot, "setColorFilter", marker)
            }
        }
    }

    // ---- Rechnerei ----

    /** Der Wochentag als Spalte, Montag zuerst – wie im Kalender der App. */
    private fun mondayFirst(cal: Calendar): Int =
        (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

    private fun weeks(today: Calendar): Int {
        val first = today.clone() as Calendar
        first.set(Calendar.DAY_OF_MONTH, 1)
        val slots = mondayFirst(first) + first.getActualMaximum(Calendar.DAY_OF_MONTH)
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

    private fun rowCount(context: Context, options: Bundle, style: RowStyle): Int =
        ((height(context, options) - HEADER_DP) / style.heightDp).coerceIn(1, 12)

    /**
     * Wie gross eine Listenzeile ausfaellt.
     *
     * Zwei Stufen, ausgesucht nach dem Platz, den die Liste bekommt. Wer ein
     * Widget in die Laenge zieht, will nicht dieselbe Miniaturschrift in
     * einer grossen Karte sehen – ab etwa drei Feldern Hoehe wird die Zeile
     * groesser, und es passen immer noch mehr hinein als vorher.
     */
    private class RowStyle(
        val heightDp: Int,
        val titleSp: Float,
        val leadSp: Float,
        val headSp: Float,
    )

    private fun rowStyle(listAreaDp: Int): RowStyle =
        if (listAreaDp >= 200) RowStyle(26, 14f, 13f, 12f)
        else RowStyle(ROW_DP, 12f, 11f, 11f)

    /** "15:00" aus der Minute seit Mitternacht. */
    private fun time(minute: Int): String? {
        if (minute < 0 || minute >= 24 * 60) return null
        val hour = minute / 60
        val rest = minute % 60
        return "${if (hour < 10) "0$hour" else "$hour"}:${if (rest < 10) "0$rest" else "$rest"}"
    }

    /** "Heute", "Morgen", sonst "Mi, 20. Aug" – wie formatRelativeDay in der App. */
    private fun relativeDay(day: Calendar, today: Calendar): String {
        val key = JoeWidgetData.dayKey(day)
        if (key == JoeWidgetData.dayKey(today)) return "Heute"
        val tomorrow = today.clone() as Calendar
        tomorrow.add(Calendar.DAY_OF_MONTH, 1)
        if (key == JoeWidgetData.dayKey(tomorrow)) return "Morgen"
        return "${WEEKDAYS[mondayFirst(day)]}, ${shortDate(day)}"
    }

    /** "20. Aug" */
    private fun shortDate(day: Calendar): String =
        "${day.get(Calendar.DAY_OF_MONTH)}. ${MONTHS_SHORT[day.get(Calendar.MONTH)]}"

    /** Dieselbe Farbe, nur leise – fuer die Trennlinie im grossen Widget. */
    private fun fade(color: Int): Int = (color and 0x00FFFFFF) or 0x33000000
}
