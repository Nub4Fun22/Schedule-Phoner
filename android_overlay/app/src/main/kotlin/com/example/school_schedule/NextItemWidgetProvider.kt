package com.example.school_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 4x2 home-screen widget that shows the next Course/Lab/Test/Exam with a
 * countdown, plus the item after it. Data is written from Flutter via
 * HomeWidget.saveWidgetData(...) and read here from SharedPreferences.
 */
class NextItemWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val title = prefs.getString("next_title", null) ?: "No upcoming items"
        val subtitle = prefs.getString("next_subtitle", null) ?: "Open the app to add some"
        val typeLabel = prefs.getString("next_type", null) ?: "Schedule Phoner"
        val countdown = prefs.getString("next_countdown", null) ?: ""
        val followingTitle = prefs.getString("following_title", null) ?: ""
        val followingSub = prefs.getString("following_sub", null) ?: ""

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_item_widget)
            views.setTextViewText(R.id.widget_type, typeLabel)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)

            // Countdown for the next item ("in 2h 15m"). Hidden when empty.
            views.setTextViewText(R.id.widget_countdown, countdown)
            views.setViewVisibility(
                R.id.widget_countdown,
                if (countdown.isEmpty()) View.GONE else View.VISIBLE
            )

            // The item after next, with its own day/time/countdown.
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
}
