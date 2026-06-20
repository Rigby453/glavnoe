package com.kaizen.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Kai-дашборд — второй домашний виджет Kaizen (ретеншн-виджет, §3/§10.4 WIDGET.md).
 *
 * Kai КРУПНЫЙ по центру + стрик 🔥N (нейтральным цветом) + X/Y главных мелко.
 * Один фиксированный layout (kai_widget.xml), размер ~3×3.
 *
 * Тот же prefs-файл "kaizen_widget", те же ключи что пишет widget_service.dart.
 * Away-логика: если last_opened_at ≥ 2 дней → emotion = "away".
 *
 * PendingIntent: requestCode 400 (уникальный, не пересекается с KaizenWidgetProvider 100-306).
 * Тап на весь виджет → widget_action="open_today".
 */
class KaizenKaiWidgetProvider : AppWidgetProvider() {

    // ─── Цвета по умолчанию (тема Focus) ────────────────────────────────────
    private val defaultSurface = "#241D11"
    private val defaultText = "#F6EFE1"
    private val defaultTextMuted = "#9E9070"
    private val defaultAccent = "#D9F24B"

    // ═══════════════════════════════════════════════════════════════════════════
    // onUpdate
    // ═══════════════════════════════════════════════════════════════════════════
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Тот же prefs-файл что читает KaizenWidgetProvider и пишет widget_service.dart
        val prefs = context.getSharedPreferences("kaizen_widget", Context.MODE_PRIVATE)

        val mainDone = prefs.getInt("main_done", 0)
        val mainTotal = prefs.getInt("main_total", 0)
        val streak = prefs.getString("streak", "0") ?: "0"
        var emotion = prefs.getString("kai_emotion", "neutral") ?: "neutral"
        val isHarsh = prefs.getBoolean("is_harsh", false)
        val lastOpenedAt = prefs.getString("last_opened_at", null)

        // Away-логика: та же что в KaizenWidgetProvider
        if (lastOpenedAt != null && Build.VERSION.SDK_INT >= 26) {
            try {
                val lastOpened = Instant.parse(lastOpenedAt)
                val daysSince = ChronoUnit.DAYS.between(lastOpened, Instant.now())
                if (daysSince >= 2) {
                    emotion = "away"
                }
            } catch (_: Exception) {
                // Не парсится ISO 8601 → оставляем emotion как есть
            }
        }

        val themeAccent = prefs.getString("theme_accent", null)
        val themeSurface = prefs.getString("theme_surface", null)
        val themeText = prefs.getString("theme_text", null)
        val themeTextMuted = prefs.getString("theme_text_muted", null)

        for (widgetId in appWidgetIds) {
            val v = buildViews(
                context = context,
                mainDone = mainDone,
                mainTotal = mainTotal,
                streak = streak,
                emotion = emotion,
                isHarsh = isHarsh,
                themeAccent = themeAccent,
                themeSurface = themeSurface,
                themeText = themeText,
                themeTextMuted = themeTextMuted,
            )
            appWidgetManager.updateAppWidget(widgetId, v)
        }
    }

    // ─── Построение RemoteViews ──────────────────────────────────────────────
    private fun buildViews(
        context: Context,
        mainDone: Int,
        mainTotal: Int,
        streak: String,
        emotion: String,
        isHarsh: Boolean,
        themeAccent: String?,
        themeSurface: String?,
        themeText: String?,
        themeTextMuted: String?,
    ): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.kai_widget)

        // ── Фон (theme_surface) ──
        val surfaceColor = safeColor(themeSurface, defaultSurface)
        v.setInt(R.id.kai_widget_root, "setBackgroundColor", surfaceColor)

        // ── Kai крупный — тот же механизм выбора PNG что в KaizenWidgetProvider ──
        val drawableName = "kai_$emotion" + if (isHarsh) "_harsh" else ""
        val resId = context.resources.getIdentifier(drawableName, "drawable", context.packageName)
        if (resId != 0) {
            v.setImageViewResource(R.id.kai_dashboard_image, resId)
        } else {
            v.setImageViewResource(R.id.kai_dashboard_image, R.drawable.kai_neutral)
        }
        // Тинтим accent-цветом (глаза белые → accent)
        val accentColor = safeColor(themeAccent, defaultAccent)
        v.setInt(R.id.kai_dashboard_image, "setColorFilter", accentColor)

        // ── Стрик нейтральным цветом ──
        val mutedColor = safeColor(themeTextMuted, defaultTextMuted)
        v.setTextViewText(R.id.kai_dashboard_streak, "🔥 ${streak}d")
        v.setTextColor(R.id.kai_dashboard_streak, mutedColor)

        // ── X/Y главных мелко ──
        val textColor = safeColor(themeText, defaultText)
        v.setTextViewText(R.id.kai_dashboard_main_progress, "$mainDone/$mainTotal")
        v.setTextColor(R.id.kai_dashboard_main_progress, textColor)

        // ── Тап на весь виджет → open_today (requestCode 400, уникальный) ──
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("widget_action", "open_today")
            }
            ?: Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("widget_action", "open_today")
            }

        val pendingFlags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        val pi = PendingIntent.getActivity(context, 400, intent, pendingFlags)
        v.setOnClickPendingIntent(R.id.kai_widget_root, pi)

        return v
    }

    /** Безопасный парсинг hex-цвета; при ошибке возвращает fallback. */
    private fun safeColor(hex: String?, fallback: String): Int {
        if (hex.isNullOrBlank()) return Color.parseColor(fallback)
        return try {
            Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            Color.parseColor(fallback)
        }
    }
}
