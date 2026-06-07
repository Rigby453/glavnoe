package com.kaizen.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "kaizen/widget"
    private val prefsName = "kaizen_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val progress = call.argument<String>("main_progress")
                        ?: "No main tasks today"
                    val streak = call.argument<String>("streak") ?: "0"
                    updateWidget(progress, streak)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// Сохраняет данные виджета и шлёт broadcast на обновление всех экземпляров.
    private fun updateWidget(progress: String, streak: String) {
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putString("main_progress", progress)
            .putString("streak", streak)
            .apply()

        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(
            ComponentName(this, KaizenWidgetProvider::class.java)
        )
        val intent = Intent(this, KaizenWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
    }
}
