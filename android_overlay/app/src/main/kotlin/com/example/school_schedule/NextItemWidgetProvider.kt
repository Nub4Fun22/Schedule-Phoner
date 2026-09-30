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
import java.util.Calendar

/**
 * 4x2 home-screen widget that shows the next Course/Lab/Seminar/Test/Exam with
 * a countdown, plus the item after it.
 *
 * The countdown is computed HERE (natively) from a stored target epoch on every
 * update, so Android's periodic widget refresh keeps the "time until" current
 * WITHOUT the app being opened. Flutter writes the data via
 * HomeWidget.saveWidgetData(...).
 */
class NextItemWidgetProvider : AppWidgetProvider() {

    companion object {
        // Custom broadcast fired by the in-widget refresh button.
        const val ACTION_REFRESH = "com.example.school_schedule.WIDGET_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Refresh the countdown on the manual button, boot / update /
        // screen-on — all without needing the app open.
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
        val title = prefs.getString("next_title", null) ?: "No upcoming items"
        val typeLabel = prefs.getString("next_type", null) ?: "Schedule Phoner"

        val now = System.currentTimeMillis()

        // --- Next item -------------------------------------------------------
        // Build "day • time • location" with a LIVE day label from the epoch,
        // so it stays correct across midnight (was frozen as "Tomorrow"
        // before). Fall back to the pushed subtitle if there's no epoch.
        val nextEpoch = parseEpoch(prefs.getString("next_epoch", null))
        val nextTime = prefs.getString("next_time", null) ?: ""
        val nextLocation = prefs.getString("next_location", null) ?: ""
        val subtitle: String
        val countdown: String
        if (nextEpoch != null) {
            val parts = ArrayList<String>()
            parts.add(dayLabel(nextEpoch, now))
            if (nextTime.isNotEmpty()) parts.add(nextTime)
            if (nextLocation.isNotEmpty()) parts.add(nextLocation)
            subtitle = parts.joinToString(" • ")
            countdown = countdownText(nextEpoch - now)
        } else {
            subtitle = prefs.getString("next_subtitle", null) ?: "Open the app to add some"
            countdown = prefs.getString("next_countdown", null) ?: ""
        }

        // --- Following item --------------------------------------------------
        val followingTitle = prefs.getString("following_title", null) ?: ""
        val followingTime = prefs.getString("following_time", null) ?: ""
        val followingEpoch = parseEpoch(prefs.getString("following_epoch", null))
        val followingSub = if (followingEpoch != null) {
            val parts = ArrayList<String>()
            parts.add(dayLabel(followingEpoch, now))
            if (followingTime.isNotEmpty()) parts.add(followingTime)
            parts.add(countdownText(followingEpoch - now))
            parts.joinToString(" • ")
        } else {
            prefs.getString("following_sub", null) ?: ""
        }

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_item_widget)
            views.setTextViewText(R.id.widget_type, typeLabel)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)

            views.setTextViewText(R.id.widget_countdown, countdown)
            views.setViewVisibility(
                R.id.widget_countdown,
                if (countdown.isEmpty()) View.GONE else View.VISIBLE
            )

            val hasFollowing = followingTitle.isNotEmpty()
            views.setTextViewText(R.id.widget_following_title, followingTitle)
            views.setTextViewText(R.id.widget_following_sub, followingSub)
            views.setViewVisibility(
                R.id.widget_following_title,
                if (hasFollowing) View.VISIBLE else View.GONE
            )
            views.setViewVisibility(
                R.id.widget_following_sub,
                if (hasFollowing) View.VISIBLE else View.GONE
            )

            // Tapping the widget body opens the app.
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            // Tapping the ↻ button refreshes the countdown in place (broadcast
            // back to this provider — works without opening the app).
            val refreshIntent = Intent(context, NextItemWidgetProvider::class.java)
                .setAction(ACTION_REFRESH)
            val refreshPending = PendingIntent.getBroadcast(
                context,
                0,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseEpoch(s: String?): Long? {
        if (s.isNullOrEmpty()) return null
        return s.toLongOrNull()
    }

    /**
     * "Today" / "Tomorrow" / weekday / dd/MM for a target epoch, computed live
     * against [nowMillis] so it's always correct (never a stale "Tomorrow").
     */
    private fun dayLabel(targetMillis: Long, nowMillis: Long): String {
        val today = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val target = Calendar.getInstance().apply { timeInMillis = targetMillis }
        // Whole-day difference (ignore the time-of-day).
        fun startOfDay(c: Calendar): Long {
            val d = c.clone() as Calendar
            d.set(Calendar.HOUR_OF_DAY, 0)
            d.set(Calendar.MINUTE, 0)
            d.set(Calendar.SECOND, 0)
            d.set(Calendar.MILLISECOND, 0)
            return d.timeInMillis
        }
        val diffDays = ((startOfDay(target) - startOfDay(today)) / 86400000L).toInt()
        return when {
            diffDays <= 0 -> "Today"
            diffDays == 1 -> "Tomorrow"
            diffDays < 7 -> when (target.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> "Monday"
                Calendar.TUESDAY -> "Tuesday"
                Calendar.WEDNESDAY -> "Wednesday"
                Calendar.THURSDAY -> "Thursday"
                Calendar.FRIDAY -> "Friday"
                Calendar.SATURDAY -> "Saturday"
                else -> "Sunday"
            }
            else -> {
                val d = target.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
                val m = (target.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
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
