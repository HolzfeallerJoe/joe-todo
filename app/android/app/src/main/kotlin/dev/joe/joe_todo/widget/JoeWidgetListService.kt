package dev.joe.joe_todo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import dev.joe.joe_todo.R
import java.util.Calendar

/**
 * Der Nachschub fuer die scrollbaren Listen.
 *
 * Eine Liste in einem Widget ist keine Reihe von Ansichten, die man
 * hinschickt, sondern eine Adapter-Verbindung: der Startbildschirm zeigt eine
 * ListView und fragt hier Zeile fuer Zeile nach, waehrend der Nutzer scrollt.
 * Vorher wurden die Zeilen fest hineingebaut, und was nicht mehr hineinpasste,
 * stand als "+3 weitere" da – jetzt ist alles erreichbar.
 *
 * Der Dienst laeuft im Prozess von Joe (der Startbildschirm bindet ihn), aber
 * ohne die App: gelesen wird wie beim Zeichnen nur der Schnappschuss.
 */
class JoeWidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        JoeWidgetListFactory(applicationContext, intent)
}

object JoeWidgetList {

    const val KIND_TASKS = "tasks"
    const val KIND_APPOINTMENTS = "appointments"

    const val EXTRA_KIND = "dev.joe.joe_todo.WIDGET_LIST_KIND"

    /**
     * Die Verbindung zu einer Liste.
     *
     * Die Adresse traegt Widget-Nummer und Art mit, weil der Startbildschirm
     * sich die Fabrik an der Intent merkt und Extras beim Vergleich zweier
     * Intents nicht mitzaehlen: ohne sie bekaemen alle Listen aller Widgets
     * dieselbe Fabrik und damit denselben Inhalt.
     */
    fun intent(context: Context, widgetId: Int, kind: String): Intent =
        Intent(context, JoeWidgetListService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_KIND, kind)
            data = Uri.parse("joe://widget/$widgetId/$kind")
        }
}

private class JoeWidgetListFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val widgetId = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID,
    )
    private val kind = intent.getStringExtra(JoeWidgetList.EXTRA_KIND)
        ?: JoeWidgetList.KIND_TASKS

    private var theme = WidgetTheme.fallback
    private var style = JoeWidgetViews.rowStyleFor(context, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var lines: List<WidgetLine> = emptyList()

    override fun onCreate() = Unit

    /**
     * Neu einlesen. Das ruft der Startbildschirm nach jedem
     * notifyAppWidgetViewDataChanged – und nur dann, deshalb steht der ganze
     * Inhalt danach fertig hier und nicht erst in [getViewAt].
     */
    override fun onDataSetChanged() {
        val snapshot = JoeWidgetData.load(context)
        theme = snapshot?.theme ?: WidgetTheme.fallback
        style = JoeWidgetViews.rowStyleFor(context, widgetId)
        val today = Calendar.getInstance()
        lines = when {
            snapshot == null -> emptyList()
            kind == JoeWidgetList.KIND_APPOINTMENTS ->
                JoeWidgetLines.appointments(snapshot, today)
            else -> JoeWidgetLines.tasks(snapshot, today)
        }
    }

    override fun onDestroy() {
        lines = emptyList()
    }

    override fun getCount(): Int = lines.size

    override fun getViewAt(position: Int): RemoteViews {
        // Zwischen zwei Abfragen kann sich die Liste geaendert haben.
        val line = lines.getOrNull(position)
            ?: return RemoteViews(context.packageName, R.layout.joe_widget_row)
        return JoeWidgetViews.line(context, theme, style, line)
    }

    /** Die Zeile und die Tagesueberschrift – zwei Layouts. */
    override fun getViewTypeCount(): Int = 2

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun getLoadingView(): RemoteViews? = null
}
