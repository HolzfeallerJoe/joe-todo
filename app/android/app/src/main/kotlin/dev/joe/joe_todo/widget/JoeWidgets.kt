package dev.joe.joe_todo.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import dev.joe.joe_todo.MainActivity
import dev.joe.joe_todo.R
import java.util.Calendar

/**
 * Die vier Widgets auf dem Startbildschirm und was sie am Leben haelt.
 *
 * Gezeichnet wird aus dem Schnappschuss, den die App hinterlegt hat
 * (JoeWidgetData). Neu gezeichnet wird bei drei Gelegenheiten:
 *
 * 1. Die App hat etwas geaendert und schiebt einen neuen Schnappschuss.
 * 2. Der Tag wechselt. Dafuer steht ein Wecker auf kurz nach Mitternacht –
 *    ungenau und "auch im Ruhezustand", denn ein exakter Alarm waere fuer ein
 *    Neuzeichnen zu viel verlangt, und ein gewoehnlicher schliefe im Doze bis
 *    zum naechsten Morgen durch.
 * 3. Als Netz darunter das updatePeriodMillis aus res/xml (halbe Stunde) und
 *    der Neustart des Telefons.
 */
abstract class JoeWidget : AppWidgetProvider() {

    /** Das Layout, das auch dann noch traegt, wenn beim Zeichnen etwas
     *  schiefgeht. */
    protected abstract val layout: Int

    protected abstract fun render(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): RemoteViews

    /** Die Listen dieses Widgets – nach jedem Zeichnen bekommen sie den
     *  Wink, ihren Inhalt neu zu holen. Leer, wo es keine gibt. */
    protected open val lists: IntArray = IntArray(0)

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        val snapshot = JoeWidgetData.load(context)
        for (id in ids) {
            show(context, manager, id, manager.getAppWidgetOptions(id), snapshot)
        }
        JoeWidgets.scheduleMidnight(context)
    }

    /** Das Widget wurde in der Groesse veraendert: Wie viele Zeilen und wie
     *  gross die Kalenderzellen sind, haengt an der Hoehe. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        show(context, manager, id, newOptions, JoeWidgetData.load(context))
    }

    override fun onEnabled(context: Context) {
        JoeWidgets.scheduleMidnight(context)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        for (id in ids) lastShown.remove(id)
    }

    override fun onDisabled(context: Context) {
        // Der letzte seiner Art ist weg – der Wecker wird nur abgestellt,
        // wenn ueberhaupt kein Joe-Widget mehr steht.
        if (!JoeWidgets.anyPlaced(context)) JoeWidgets.cancelMidnight(context)
    }

    /**
     * Zeichnen – aber nur, wenn sich seit dem letzten Mal wirklich etwas
     * geaendert hat.
     *
     * **Ohne diese Bremse dreht sich das Ganze im Kreis, und zwar bis der
     * Startbildschirm steht.** Ein `updateAppWidget` laesst den fremden
     * Prozess die Ansicht neu vermessen; faellt sie dabei anders aus als
     * vorher, meldet er die neue Groesse zurueck, das System ruft
     * [onAppWidgetOptionsChanged], und wenn *das* wieder blind zeichnet,
     * geht es von vorn los. Genau das ist passiert: hunderte Updates in
     * Sekunden, danach "System UI reagiert nicht" – und damit ein schwarzer
     * Bildschirm fuer *alle* Apps, nicht nur fuer Joe.
     *
     * Die Unterschrift deckt alles ab, wovon das Bild abhaengt: Groesse,
     * Datenstand und der Tag (um Mitternacht aendert sich das Bild ohne neue
     * Daten).
     */
    private fun show(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ) {
        val signature = buildString {
            append(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)).append('x')
            append(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)).append('x')
            append(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)).append('x')
            append(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)).append('|')
            append(JoeWidgetData.dayKey(Calendar.getInstance())).append('|')
            append(snapshot?.stamp ?: 0)
        }
        if (lastShown[id] == signature) return
        Log.d(TAG, "zeichne $id ($signature)")
        val built = build(context, id, options, snapshot)
        try {
            manager.updateAppWidget(id, built.views)
            // Die Liste haengt an einer Verbindung, nicht an der
            // Bauanleitung: ohne diesen Wink haelt der Startbildschirm an
            // dem fest, was er sich beim letzten Mal geholt hat.
            //
            // Der Weg ueber den Dienst gilt inzwischen als veraltet; der
            // Nachfolger (die Zeilen gleich mitschicken) gibt es aber erst ab
            // Android 12, und Joe laeuft auch darunter.
            @Suppress("DEPRECATION")
            for (list in lists) manager.notifyAppWidgetViewDataChanged(id, list)
            // Nur ein wirklich fertig gezeichnetes Widget darf kuenftige
            // Aktualisierungen mit derselben Signatur ausbremsen. Die leere
            // Ersatzkarte wird dagegen beim naechsten System-Tick erneut
            // versucht.
            if (built.complete) lastShown[id] = signature else lastShown.remove(id)
        } catch (e: Exception) {
            lastShown.remove(id)
            Log.w(TAG, "Widget-Aktualisierung fehlgeschlagen", e)
        }
    }

    /**
     * Kein Fehler beim Zeichnen darf nach aussen dringen: eine Ausnahme in
     * onUpdate laesst den Startbildschirm "Widget kann nicht geladen werden"
     * anzeigen, und da kommt der Nutzer ohne Neuanlegen nicht wieder raus.
     * Dann lieber die leere Karte.
     */
    private class BuiltWidget(val views: RemoteViews, val complete: Boolean)

    private fun build(
        context: Context,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?,
    ): BuiltWidget =
        try {
            BuiltWidget(render(context, widgetId, options, snapshot), true)
        } catch (e: Exception) {
            Log.w(TAG, "Zeichnen fehlgeschlagen", e)
            BuiltWidget(RemoteViews(context.packageName, layout), false)
        }

    companion object {
        const val TAG = "JoeWidget"

        /** Was zu jeder Widget-Nummer zuletzt gezeichnet wurde. Ueberlebt so
         *  lange wie der Prozess; danach wird einmal neu gezeichnet, was
         *  nicht schadet. */
        private val lastShown = HashMap<Int, String>()
    }
}

/** 2x2: die Aufgaben von heute. */
class JoeTasksWidget : JoeWidget() {
    override val layout = R.layout.joe_widget_tasks
    override val lists = intArrayOf(R.id.joe_list)
    override fun render(context: Context, widgetId: Int, options: Bundle, snapshot: WidgetSnapshot?) =
        JoeWidgetViews.tasks(context, widgetId, options, snapshot)
}

/** 2x2: die naechsten Termine. */
class JoeAppointmentsWidget : JoeWidget() {
    override val layout = R.layout.joe_widget_appointments
    override val lists = intArrayOf(R.id.joe_list)
    override fun render(context: Context, widgetId: Int, options: Bundle, snapshot: WidgetSnapshot?) =
        JoeWidgetViews.appointments(context, widgetId, options, snapshot)
}

/** 2x2: der laufende Monat. */
class JoeCalendarWidget : JoeWidget() {
    override val layout = R.layout.joe_widget_calendar
    override fun render(context: Context, widgetId: Int, options: Bundle, snapshot: WidgetSnapshot?) =
        JoeWidgetViews.calendar(context, widgetId, options, snapshot)
}

/** Der grosse Block: Kalender, Aufgaben und Termine zusammen. */
class JoeOverviewWidget : JoeWidget() {
    override val layout = R.layout.joe_widget_overview
    override val lists = intArrayOf(R.id.joe_list, R.id.joe_list_two)
    override fun render(context: Context, widgetId: Int, options: Bundle, snapshot: WidgetSnapshot?) =
        JoeWidgetViews.overview(context, widgetId, options, snapshot)
}

/**
 * Der Tageswechsel und der Neustart. Beides ist derselbe Handgriff: alles
 * neu zeichnen und den naechsten Wecker stellen (nach einem Neustart sind
 * alle Wecker weg).
 */
class JoeWidgetTick : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        JoeWidgets.updateAll(context)
        JoeWidgets.scheduleMidnight(context)
    }
}

object JoeWidgets {
    const val TARGET_TASKS = "tasks"
    const val TARGET_APPOINTMENTS = "appointments"
    const val TARGET_CALENDAR = "calendar"

    /** Wohin ein angetipptes Widget fuehren soll – die App liest das in
     *  lib/home_widget.dart wieder aus. */
    const val EXTRA_TARGET = "dev.joe.joe_todo.WIDGET_TARGET"

    private const val ACTION_TICK = "dev.joe.joe_todo.WIDGET_TICK"
    private const val ACTION_OPEN = "dev.joe.joe_todo.WIDGET_OPEN"

    private val providers = listOf(
        JoeTasksWidget::class.java,
        JoeAppointmentsWidget::class.java,
        JoeCalendarWidget::class.java,
        JoeOverviewWidget::class.java,
    )

    /**
     * Der Weg vom Widget in die App.
     *
     * Bewusst mit eigener Aktion und eigener Adresse statt mit MAIN/LAUNCHER:
     * ein Start "wie vom Startbildschirm" holt eine laufende App nur nach
     * vorn, ohne die Intent zuzustellen – das Ziel ginge unterwegs verloren.
     * Die Adresse macht ausserdem die drei Absichten unterscheidbar; Extras
     * allein zaehlen beim Vergleich zweier PendingIntents nicht mit.
     *
     * Kein FLAG_ACTIVITY_NEW_TASK: die Activity traegt `taskAffinity=""`
     * (so kommt die Vorlage von Flutter), und mit leerer Affinitaet macht
     * NEW_TASK aus jedem Antipper eine *neue* Aufgabe statt die vorhandene
     * nach vorn zu holen – mitsamt Uebergangsanimation auf ein Fenster, das
     * gerade erst seine Oberflaeche bekommt. Was PendingIntent.getActivity
     * an Flags wirklich braucht, ergaenzt das System von selbst; so laeuft
     * der Weg genauso wie beim Antippen einer Erinnerung, und der ist in
     * dieser App erprobt.
     */
    fun open(context: Context, target: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            target.hashCode(),
            openIntent(context, target),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /**
     * Derselbe Weg, aber als Vorlage fuer die Zeilen einer scrollbaren Liste.
     *
     * Eine Liste setzt nicht auf jede Zeile eine eigene Absicht, sondern eine
     * Vorlage auf die Liste und auf jede Zeile eine Ergaenzung dazu. Die
     * Vorlage muss deshalb veraenderbar sein – eine unveraenderliche liesse
     * sich nicht ergaenzen, und ab Android 12 wirft das System die Zeile
     * gleich ganz weg. Joe ergaenzt nichts, aber die Regel gilt trotzdem.
     */
    fun openTemplate(context: Context, target: String): PendingIntent {
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        return PendingIntent.getActivity(
            context,
            "template:$target".hashCode(),
            openIntent(context, target),
            PendingIntent.FLAG_UPDATE_CURRENT or mutable,
        )
    }

    private fun openIntent(context: Context, target: String): Intent =
        Intent(context, MainActivity::class.java)
            .setAction(ACTION_OPEN)
            .setData(Uri.parse("joe://widget/$target"))
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(EXTRA_TARGET, target)

    /** Alle gesetzten Joe-Widgets neu zeichnen lassen. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids == null || ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(context, provider)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            )
        }
    }

    fun anyPlaced(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context) ?: return false
        return providers.any {
            manager.getAppWidgetIds(ComponentName(context, it))?.isNotEmpty() == true
        }
    }

    /**
     * Der Wecker auf kurz nach Mitternacht. Er wird bei jedem Zeichnen neu
     * gestellt – ein Wecker, der einmal ausgefallen ist, holt sich so von
     * selbst wieder ein.
     */
    fun scheduleMidnight(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            // Ein paar Sekunden Luft: genau um 0:00:00 ist der neue Tag noch
            // eine Wette auf die Rundung.
            set(Calendar.SECOND, 10)
            set(Calendar.MILLISECOND, 0)
        }
        try {
            // Ungenau, aber nicht verschlafen: setAndAllowWhileIdle kommt
            // auch im Doze durch. Ein exakter Alarm waere fuers Neuzeichnen
            // eines Widgets nicht zu rechtfertigen.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC, next.timeInMillis, tick(context))
            } else {
                alarms.set(AlarmManager.RTC, next.timeInMillis, tick(context))
            }
        } catch (e: Exception) {
            // Ohne Wecker bleibt das Netz aus updatePeriodMillis.
            Log.w("JoeWidget", "Wecker fuer Mitternacht nicht gestellt", e)
        }
    }

    fun cancelMidnight(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarms.cancel(tick(context))
    }

    private fun tick(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, JoeWidgetTick::class.java).setAction(ACTION_TICK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
