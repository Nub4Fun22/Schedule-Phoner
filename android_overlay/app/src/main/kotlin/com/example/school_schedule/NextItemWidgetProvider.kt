package com.example.school_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 3x1 home-screen widget that shows the next Course/Lab/Test/Exam.
 * Data is written from Flutter via HomeWidget.saveWidgetData(...) and read here
 * from the plugin's SharedPreferences.
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
        val following = prefs.getString("following", null) ?: ""

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_item_widget)
            views.setTextViewText(R.id.widget_type, typeLabel)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)

            // Countdown ("in 2h 15m"). Hide the view when there's nothing.
            views.setTextViewText(R.id.widget_countdown, countdown)
            views.setViewVisibility(
                R.id.widget_countdown,
                if (countdown.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE
            )

            // "Next: ..." second upcoming item. Hidden when empty.
            views.setTextViewText(R.id.widget_following, following)
            views.setViewVisibility(
                R.id.widget_following,
                if (following.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE
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
