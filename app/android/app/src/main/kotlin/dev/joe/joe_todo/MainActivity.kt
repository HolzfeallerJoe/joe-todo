package dev.joe.joe_todo

import android.content.Intent
import android.util.Log
import dev.joe.joe_todo.widget.JoeWidget
import dev.joe.joe_todo.widget.JoeWidgetData
import dev.joe.joe_todo.widget.JoeWidgets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Die Bruecke zu den Startbildschirm-Widgets.
 *
 * Zwei Richtungen: Die App schiebt ihren Schnappschuss herunter ("push"), und
 * ein angetipptes Widget schickt sein Ziel hinauf. Fuer das Ziel gibt es zwei
 * Wege, und beide werden gebraucht – beim Kaltstart steht es schon in der
 * Intent, bevor Dart ueberhaupt laeuft (das holt sich die App mit
 * "launchTarget" ab, sobald sie steht), bei laufender App kommt es als
 * onNewIntent herein.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var expiryChannel: MethodChannel? = null

    /** Das Ziel, das noch niemand abgeholt hat. */
    private var pendingTarget: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        intent?.getStringExtra(JoeWidgets.EXTRA_TARGET)?.let { pendingTarget = it }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "push" -> {
                    val json = call.arguments as? String
                    if (json == null) {
                        result.error("kein_schnappschuss", "Erwartet wird JSON", null)
                    } else {
                        // Nur wenn sich wirklich etwas geaendert hat: jeder
                        // Rundruf laesst vier Widgets im Prozess des
                        // Startbildschirms neu zeichnen.
                        val changed = JoeWidgetData.save(applicationContext, json)
                        Log.d(JoeWidget.TAG, "Schnappschuss: " +
                            if (changed) "neu (${json.length} Zeichen)" else "unveraendert")
                        if (changed) JoeWidgets.updateAll(applicationContext)
                        result.success(changed)
                    }
                }

                "launchTarget" -> {
                    result.success(pendingTarget)
                    pendingTarget = null
                }

                else -> result.notImplemented()
            }
        }
        this.channel = channel

        // Hinweise vor dem Entteilen geteilter Listen, siehe SharedExpiry.
        val expiry = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPIRY_CHANNEL)
        expiry.setMethodCallHandler { call, result ->
            val key = call.argument<String>("key")
            when {
                key == null -> result.error("kein_schluessel", "key fehlt", null)
                call.method == "schedule" -> {
                    val title = call.argument<String>("title")
                    val url = call.argument<String>("url")
                    val token = call.argument<String>("token")
                    val runAt = call.argument<Number>("runAt")?.toLong()
                    if (title == null || url == null || token == null || runAt == null) {
                        result.error("unvollstaendig", "title, url, token, runAt", null)
                    } else {
                        SharedExpiry.schedule(applicationContext, key, title, url, token, runAt)
                        result.success(null)
                    }
                }
                call.method == "cancel" -> {
                    SharedExpiry.cancel(applicationContext, key)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        expiryChannel = expiry
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val target = intent.getStringExtra(JoeWidgets.EXTRA_TARGET) ?: return
        val channel = this.channel
        // Steht der Kanal noch nicht, wartet das Ziel auf "launchTarget" –
        // verloren gehen darf es nicht.
        if (channel == null) pendingTarget = target else channel.invokeMethod("open", target)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        expiryChannel?.setMethodCallHandler(null)
        expiryChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val CHANNEL = "joe/home_widget"
        private const val EXPIRY_CHANNEL = "joe/shared_expiry"
    }
}
