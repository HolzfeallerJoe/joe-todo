package dev.joe.joe_todo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Die zweite Stufe der Hinweise vor dem Entteilen (Konzept 6.6, Variante B),
 * nur beim Ersteller einer geteilten Einkaufsliste.
 *
 * Kurz nach der Frist fragt ein WorkManager-Auftrag einmal `meta` mit dem
 * Ersteller-Token. Antwortet der Server `410 expired`, kommt die
 * Benachrichtigung "wird nicht mehr geteilt". Hat inzwischen jemand die
 * Liste benutzt, nennt er eine neue Frist, und der Auftrag plant sich darauf
 * um. Ohne Netz wiederholt WorkManager mit Wartezeit (Bedingung "verbunden").
 *
 * Bewusst ganz ohne Dart: im Hintergrund muss dafuer keine Flutter-Engine
 * starten. Die App reicht Adresse, Token, Titel und Zeitpunkt herein
 * (lib/shared_expiry.dart).
 *
 * Ins Log kommen weder Adresse noch Token.
 */
object SharedExpiry {
    const val TAG = "JoeSharedExpiry"
    const val CHANNEL_ID = "joe_shared_lists"

    private const val KEY = "key"
    private const val TITLE = "title"
    private const val URL_KEY = "url"
    private const val TOKEN = "token"

    private fun workName(key: String) = "joe-shared-expiry-$key"

    fun schedule(context: Context, key: String, title: String, url: String, token: String, runAt: Long) {
        val delay = (runAt - System.currentTimeMillis()).coerceAtLeast(0)
        val request = OneTimeWorkRequestBuilder<SharedExpiryWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build(),
            )
            .setInputData(
                Data.Builder()
                    .putString(KEY, key)
                    .putString(TITLE, title)
                    .putString(URL_KEY, url)
                    .putString(TOKEN, token)
                    .build(),
            )
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(workName(key), ExistingWorkPolicy.REPLACE, request)
        Log.d(TAG, "geplant in ${delay / 3_600_000} h")
    }

    fun cancel(context: Context, key: String) {
        WorkManager.getInstance(context).cancelUniqueWork(workName(key))
    }

    internal fun inputs(data: Data): Inputs? {
        val key = data.getString(KEY) ?: return null
        val title = data.getString(TITLE) ?: return null
        val url = data.getString(URL_KEY) ?: return null
        val token = data.getString(TOKEN) ?: return null
        return Inputs(key, title, url, token)
    }

    internal data class Inputs(val key: String, val title: String, val url: String, val token: String)

    fun notifyUnshared(context: Context, key: String, title: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Geteilte Listen", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Hinweise, bevor eine geteilte Einkaufsliste nicht mehr geteilt wird"
                },
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val tap = launch?.let {
            PendingIntent.getActivity(
                context,
                key.hashCode(),
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val text = "Sie bleibt auf deinem Gerät, gleicht aber nicht mehr ab."
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("„$title“ wird nicht mehr geteilt")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .apply { if (tap != null) setContentIntent(tap) }
            .build()
        try {
            manager.notify(key.hashCode(), notification)
        } catch (e: SecurityException) {
            // Ohne POST_NOTIFICATIONS (Android 13+, abgelehnt): nichts zu tun,
            // die App zeigt es beim naechsten Oeffnen.
            Log.d(TAG, "Benachrichtigung nicht erlaubt")
        }
    }
}

class SharedExpiryWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val inputs = SharedExpiry.inputs(inputData) ?: return Result.failure()
        val connection = try {
            URL(inputs.url).openConnection() as HttpURLConnection
        } catch (e: IOException) {
            return Result.retry()
        }
        return try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("X-Joe-Owner", inputs.token)
            val code = connection.responseCode
            val stream = if (code < 400) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() } ?: ""
            when {
                code == 200 -> {
                    // Jemand hat die Liste benutzt: auf die neue Frist umplanen.
                    val expires = JSONObject(body).optString("expiresAt", "")
                    if (expires.isNotEmpty()) {
                        val next = Instant.parse(expires).toEpochMilli() + 3_600_000
                        if (next > System.currentTimeMillis()) {
                            SharedExpiry.schedule(
                                applicationContext, inputs.key, inputs.title, inputs.url, inputs.token, next,
                            )
                        }
                    }
                    Log.d(SharedExpiry.TAG, "noch geteilt")
                    Result.success()
                }
                code == 410 -> {
                    val reason = runCatching { JSONObject(body).optString("reason") }.getOrDefault("")
                    // "deleted": das war der Ersteller selbst, kein Hinweis noetig.
                    if (reason == "expired") {
                        SharedExpiry.notifyUnshared(applicationContext, inputs.key, inputs.title)
                    }
                    Log.d(SharedExpiry.TAG, "nicht mehr geteilt ($reason)")
                    Result.success()
                }
                code == 429 || code >= 500 -> Result.retry()
                // 404 (Server hat sie verloren, die App legt sie neu an), 403
                // und alles andere: nichts zu melden.
                else -> Result.success()
            }
        } catch (e: IOException) {
            Result.retry()
        } catch (e: Exception) {
            Log.d(SharedExpiry.TAG, "Nachfrage fehlgeschlagen: ${e.javaClass.simpleName}")
            Result.success()
        } finally {
            connection.disconnect()
        }
    }
}
