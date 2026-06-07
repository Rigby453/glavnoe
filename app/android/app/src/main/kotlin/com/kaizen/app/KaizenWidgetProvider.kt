package com.kaizen.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/**
 * Домашний виджет Kaizen.
 *
 * Чистый AppWidgetProvider без сторонних плагинов. Данные пишет нативный
 * MainActivity (по MethodChannel из Flutter) в SharedPreferences "kaizen_widget";
 * здесь только читаем и отрисовываем. Тап по виджету открывает приложение.
 */
class KaizenWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(
            "kaizen_widget",
            Context.MODE_PRIVATE
        )
        val progress = prefs.getString("main_progress", "No main tasks today")
        val streak = prefs.getString("streak", "0")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kaizen_widget)
            views.setTextViewText(R.id.widget_progress, progress)
            views.setTextViewText(R.id.widget_streak, "🔥 $streak")

            // Тап по виджету открывает приложение
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                var flags = PendingIntent.FLAG_UPDATE_CURRENT
                if (Build.VERSION.SDK_INT >= 23) {
                    flags = flags or PendingIntent.FLAG_IMMUTABLE
                }
                val pendingIntent =
                    PendingIntent.getActivity(context, 0, launchIntent, flags)
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
