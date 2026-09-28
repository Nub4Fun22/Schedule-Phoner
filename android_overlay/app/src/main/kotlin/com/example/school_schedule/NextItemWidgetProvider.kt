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
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Refresh the countdown on boot / update / screen-on without the app.
        when (intent.action) {
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
        val subtitle = prefs.getString("next_subtitle", null) ?: "Open the app to add some"
        val typeLabel = prefs.getString("next_type", null) ?: "Schedule Phoner"

        val now = System.currentTimeMillis()

        // Live countdown for the next item (fall back to the pushed string).
        val nextEpoch = parseEpoch(prefs.getString("next_epoch", null))
        val countdown = if (nextEpoch != null) {
            countdownText(nextEpoch - now)
        } else {
            prefs.getString("next_countdown", null) ?: ""
        }

        val followingTitle = prefs.getString("following_title", null) ?: ""
        val followingPrefix = prefs.getString("following_prefix", null) ?: ""
        val followingEpoch = parseEpoch(prefs.getString("following_epoch", null))
        val followingSub = if (followingEpoch != null && followingPrefix.isNotEmpty()) {
            followingPrefix + countdownText(followingEpoch - now)
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

            // Tapping the widget opens the app.
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

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseEpoch(s: String?): Long? {
        if (s.isNullOrEmpty()) return null
        return s.toLongOrNull()
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
