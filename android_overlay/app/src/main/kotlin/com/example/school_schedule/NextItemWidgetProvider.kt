package com.example.school_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.util.Calendar

/**
 * 4x2 home-screen widget showing the next Course/Lab/Seminar/Test/Exam with a
 * live countdown, plus the item after it.
 *
 * The app pushes an ORDERED LIST of upcoming occurrences (JSON, key
 * "occurrences"). On every widget update this provider:
 *   1. drops occurrences whose start time has already passed (with a short
 *      grace period so an in-progress item lingers briefly), then
 *   2. shows the first two that remain, computing each item's day label
 *      ("Today"/"Tomorrow"/weekday) AND countdown NATIVELY from its epoch.
 *
 * So the widget rolls over to the next event and keeps labels/countdowns
 * correct across midnight WITHOUT the app being opened.
 */
class NextItemWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_REFRESH = "com.example.school_schedule.WIDGET_REFRESH"
        // Keep a passed event visible for a few minutes before rolling over.
        const val GRACE_MILLIS = 5 * 60 * 1000L
    }

    private data class Occ(
        val epoch: Long,
        val type: String,
        val title: String,
        val time: String,
        val location: String,
    )

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_SCREEN_ON,
            "android.intent.action.QUICKBOOT_POWERON" -> refreshAll(context)
        }
    }

    private fun refreshAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context) ?: return
        val ids = mgr.getAppWidgetIds(
            ComponentName(context, NextItemWidgetProvider::class.java))
        if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()

        // Parse and filter the pushed occurrences: keep only those not yet
        // passed (minus a short grace), sorted soonest-first.
        val all = parseOccurrences(prefs.getString("occurrences", null))
        val upcoming = all
            .filter { it.epoch >= now - GRACE_MILLIS }
            .sortedBy { it.epoch }

        val next = upcoming.getOrNull(0)
        val following = upcoming.getOrNull(1)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_item_widget)

            if (next == null) {
                views.setTextViewText(R.id.widget_type, "Schedule Phoner")
                views.setTextViewText(R.id.widget_title, "No upcoming items")
                views.setTextViewText(R.id.widget_subtitle, "Open the app to add some")
                views.setViewVisibility(R.id.widget_countdown, View.GONE)
                views.setViewVisibility(R.id.widget_following_title, View.GONE)
                views.setViewVisibility(R.id.widget_following_sub, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_type, next.type)
                views.setTextViewText(R.id.widget_title, next.title)
                views.setTextViewText(R.id.widget_subtitle, subtitleFor(next, now))
                val cd = countdownText(next.epoch - now)
                views.setTextViewText(R.id.widget_countdown, cd)
                views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)

                if (following == null) {
                    views.setViewVisibility(R.id.widget_following_title, View.GONE)
                    views.setViewVisibility(R.id.widget_following_sub, View.GONE)
                } else {
                    views.setTextViewText(
                        R.id.widget_following_title,
                        "${following.type}: ${following.title}")
                    views.setTextViewText(
                        R.id.widget_following_sub, followingSubFor(following, now))
                    views.setViewVisibility(R.id.widget_following_title, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_following_sub, View.VISIBLE)
                }
            }

            // Tapping the widget body opens the app.
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pending = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            // ↻ button: refresh in place via a broadcast to this provider.
            val refreshIntent = Intent(context, NextItemWidgetProvider::class.java)
                .setAction(ACTION_REFRESH)
            val refreshPending = PendingIntent.getBroadcast(
                context, 0, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseOccurrences(json: String?): List<Occ> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val arr = JSONArray(json)
            val out = ArrayList<Occ>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                out.add(
                    Occ(
                        epoch = o.optLong("epoch", 0L),
                        type = o.optString("type", ""),
                        title = o.optString("title", ""),
                        time = o.optString("time", ""),
                        location = o.optString("location", ""),
                    )
                )
            }
            out
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** "Today • 08:00 • Room A1" — day label computed live from the epoch. */
    private fun subtitleFor(o: Occ, now: Long): String {
        val parts = ArrayList<String>()
        parts.add(dayLabel(o.epoch, now))
        if (o.time.isNotEmpty()) parts.add(o.time)
        if (o.location.isNotEmpty()) parts.add(o.location)
        return parts.joinToString(" • ")
    }

    /** "Wed • 10:00 • in 1d 2h" for the second item. */
    private fun followingSubFor(o: Occ, now: Long): String {
        val parts = ArrayList<String>()
        parts.add(dayLabel(o.epoch, now))
        if (o.time.isNotEmpty()) parts.add(o.time)
        parts.add(countdownText(o.epoch - now))
        return parts.joinToString(" • ")
    }

    /** "Today"/"Tomorrow"/weekday/dd/MM for a target epoch vs now. */
    private fun dayLabel(targetMillis: Long, nowMillis: Long): String {
        fun startOfDay(millis: Long): Long {
            val c = Calendar.getInstance().apply {
                timeInMillis = millis
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return c.timeInMillis
        }
        val diffDays =
            ((startOfDay(targetMillis) - startOfDay(nowMillis)) / 86400000L).toInt()
        return when {
            diffDays <= 0 -> "Today"
            diffDays == 1 -> "Tomorrow"
            diffDays < 7 -> {
                val c = Calendar.getInstance().apply { timeInMillis = targetMillis }
                when (c.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.MONDAY -> "Monday"
                    Calendar.TUESDAY -> "Tuesday"
                    Calendar.WEDNESDAY -> "Wednesday"
                    Calendar.THURSDAY -> "Thursday"
                    Calendar.FRIDAY -> "Friday"
                    Calendar.SATURDAY -> "Saturday"
                    else -> "Sunday"
                }
            }
            else -> {
                val c = Calendar.getInstance().apply { timeInMillis = targetMillis }
                val d = c.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
                val m = (c.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
                "$d/$m"
            }
        }
    }

    /** "now" / "in 45m" / "in 2h 15m" / "in 3d 4h" from a millis delta. */
    private fun countdownText(deltaMillis: Long): String {
        if (deltaMillis <= 0) return "now"
        val totalMinutes = deltaMillis / 60000L
        if (totalMinutes < 60) return "in ${totalMinutes}m"
        val totalHours = totalMinutes / 60
        if (totalHours < 24) {
            val m = totalMinutes % 60
            return if (m > 0) "in ${totalHours}h ${m}m" else "in ${totalHours}h"
        }
        val days = totalHours / 24
        val hours = totalHours % 24
        return if (hours > 0) "in ${days}d ${hours}h" else "in ${days}d"
    }
}
