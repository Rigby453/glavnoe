package com.kaizen.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONException
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Домашний виджет Kaizen — Фаза 2 (task-focused, адаптивный по размеру).
 *
 * Три раскладки:
 *   - kaizen_widget_small  (2×2): 1 пункт + X/Y мелко + стрик + Kai-уголок
 *   - kaizen_widget_medium (4×2): 2 пункта + X/Y + стрик + Kai справа-сверху
 *   - kaizen_widget_large  (4×4): до 4 пунктов + X/Y + стрик + Kai + кнопка «+»
 *
 * API 31+ → responsive RemoteViews (SizeF map); < API 31 → выбор по appWidgetOptions.
 *
 * Темизация: цвета приходят из SharedPreferences (Flutter пишет через MethodChannel).
 * Away-логика: если last_opened_at старше 2 дней — emotion переопределяется в "away".
 */
class KaizenWidgetProvider : AppWidgetProvider() {

    // ─── Цвета по умолчанию (тема Focus) ────────────────────────────────────
    private val defaultSurface = "#241D11"
    private val defaultText = "#F6EFE1"
    private val defaultTextMuted = "#9E9070"
    private val defaultAccent = "#D9F24B"

    // ─── Пороги размера (dp) для выбора раскладки без responsive API ─────────
    // Ячейка в dp ≈ 70–80dp. 2 столбца ≈ 160dp, 4 столбца ≈ 250dp.
    private val mediumMinWidthDp = 200   // ≥ 200dp ширина → не small
    private val largeMinHeightDp = 200   // ≥ 200dp высота → large

    // ─── Символы типов задач ─────────────────────────────────────────────────
    private fun typeIcon(type: String?): String = when (type) {
        "event" -> "◆"
        "exam" -> "★"
        "deadline" -> "⚑"
        "task" -> "●"
        else -> "•"
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // onUpdate — системный колбэк обновления (на broadcast + по таймеру)
    // ═══════════════════════════════════════════════════════════════════════════
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("kaizen_widget", Context.MODE_PRIVATE)
        val data = WidgetData.from(prefs)

        for (widgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, widgetId, data)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // onAppWidgetOptionsChanged — вызывается при изменении размера виджета
    // ═══════════════════════════════════════════════════════════════════════════
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val prefs = context.getSharedPreferences("kaizen_widget", Context.MODE_PRIVATE)
        val data = WidgetData.from(prefs)
        updateSingleWidget(context, appWidgetManager, appWidgetId, data)
    }

    // ─── Главная функция рендеринга одного экземпляра виджета ────────────────
    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: WidgetData
    ) {
        // PendingIntent — тап открывает приложение
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingFlags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        val openAppPending: PendingIntent? = launchIntent?.let {
            PendingIntent.getActivity(context, 0, it, pendingFlags)
        }

        if (Build.VERSION.SDK_INT >= 31) {
            // ── API 31+: Responsive RemoteViews (система выбирает по реальному размеру) ──
            val smallViews = buildSmallViews(context, data, openAppPending)
            val mediumViews = buildMediumViews(context, data, openAppPending)
            val largeViews = buildLargeViews(context, data, openAppPending)

            // SizeF(width, height) в dp — система сопоставляет с реальным размером виджета
            val viewsMap = mapOf(
                SizeF(110f, 110f) to smallViews,     // 2×2
                SizeF(250f, 110f) to mediumViews,    // 4×2
                SizeF(250f, 280f) to largeViews      // 4×4
            )
            val responsiveViews = RemoteViews(viewsMap)
            appWidgetManager.updateAppWidget(widgetId, responsiveViews)
        } else {
            // ── < API 31: Выбор по appWidgetOptions (minWidth/minHeight) ──
            val opts = appWidgetManager.getAppWidgetOptions(widgetId)
            val minW = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val minH = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)

            val views = when {
                minH >= largeMinHeightDp -> buildLargeViews(context, data, openAppPending)
                minW >= mediumMinWidthDp -> buildMediumViews(context, data, openAppPending)
                else -> buildSmallViews(context, data, openAppPending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Построители RemoteViews для каждого размера
    // ═══════════════════════════════════════════════════════════════════════════

    private fun buildSmallViews(
        context: Context,
        data: WidgetData,
        openApp: PendingIntent?
    ): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.kaizen_widget_small)

        // Тап на весь виджет → открыть приложение
        openApp?.let { v.setOnClickPendingIntent(R.id.widget_root_small, it) }

        // Цвета
        applyBgColor(v, R.id.widget_root_small, data)

        val textColor = safeColor(data.themeText, defaultText)
        val mutedColor = safeColor(data.themeTextMuted, defaultTextMuted)

        // Первый пункт
        val first = data.nextItems.getOrNull(0)
        if (first != null) {
            v.setTextViewText(R.id.small_time, first.time)
            v.setTextViewText(R.id.small_title, first.title)
        } else {
            v.setTextViewText(R.id.small_time, "")
            v.setTextViewText(R.id.small_title, context.getString(R.string.widget_nothing_today))
        }
        v.setTextColor(R.id.small_time, textColor)
        v.setTextColor(R.id.small_title, textColor)

        // X/Y главных
        v.setTextViewText(R.id.small_main_progress, "${data.mainDone}/${data.mainTotal}")
        v.setTextColor(R.id.small_main_progress, textColor)

        // Стрик — нейтральным цветом (не accent)
        v.setTextViewText(R.id.small_streak, "🔥${data.streak}d")
        v.setTextColor(R.id.small_streak, mutedColor)

        // Kai
        applyKai(context, v, R.id.kai_image_small, data)
        openApp?.let { v.setOnClickPendingIntent(R.id.kai_image_small, it) }

        return v
    }

    private fun buildMediumViews(
        context: Context,
        data: WidgetData,
        openApp: PendingIntent?
    ): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.kaizen_widget_medium)

        openApp?.let { v.setOnClickPendingIntent(R.id.widget_root_medium, it) }
        applyBgColor(v, R.id.widget_root_medium, data)

        val textColor = safeColor(data.themeText, defaultText)
        val mutedColor = safeColor(data.themeTextMuted, defaultTextMuted)

        // Стрик
        v.setTextViewText(R.id.medium_streak, "🔥${data.streak}d")
        v.setTextColor(R.id.medium_streak, mutedColor)

        // X/Y главных
        v.setTextViewText(R.id.medium_main_progress, "${data.mainDone}/${data.mainTotal} main")
        v.setTextColor(R.id.medium_main_progress, textColor)

        // Пункт 1
        val first = data.nextItems.getOrNull(0)
        if (first != null) {
            v.setViewVisibility(R.id.medium_row1, View.VISIBLE)
            v.setTextViewText(R.id.medium_time1, first.time)
            v.setTextColor(R.id.medium_time1, textColor)
            v.setTextViewText(R.id.medium_icon1, typeIcon(first.type))
            v.setTextColor(R.id.medium_icon1, mutedColor)
            v.setTextViewText(R.id.medium_title1, first.title)
            v.setTextColor(R.id.medium_title1, textColor)
            openApp?.let { v.setOnClickPendingIntent(R.id.medium_row1, it) }
        } else {
            v.setViewVisibility(R.id.medium_row1, View.VISIBLE)
            v.setTextViewText(R.id.medium_time1, "")
            v.setTextViewText(R.id.medium_icon1, "")
            v.setTextViewText(R.id.medium_title1, context.getString(R.string.widget_nothing_today))
            v.setTextColor(R.id.medium_title1, mutedColor)
        }

        // Пункт 2
        val second = data.nextItems.getOrNull(1)
        if (second != null) {
            v.setViewVisibility(R.id.medium_row2, View.VISIBLE)
            v.setTextViewText(R.id.medium_time2, second.time)
            v.setTextColor(R.id.medium_time2, textColor)
            v.setTextViewText(R.id.medium_icon2, typeIcon(second.type))
            v.setTextColor(R.id.medium_icon2, mutedColor)
            v.setTextViewText(R.id.medium_title2, second.title)
            v.setTextColor(R.id.medium_title2, textColor)
            openApp?.let { v.setOnClickPendingIntent(R.id.medium_row2, it) }
        } else {
            v.setViewVisibility(R.id.medium_row2, View.GONE)
        }

        // Kai
        applyKai(context, v, R.id.kai_image_medium, data)
        openApp?.let { v.setOnClickPendingIntent(R.id.kai_image_medium, it) }

        return v
    }

    private fun buildLargeViews(
        context: Context,
        data: WidgetData,
        openApp: PendingIntent?
    ): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.kaizen_widget_large)

        openApp?.let { v.setOnClickPendingIntent(R.id.widget_root_large, it) }
        applyBgColor(v, R.id.widget_root_large, data)

        val textColor = safeColor(data.themeText, defaultText)
        val mutedColor = safeColor(data.themeTextMuted, defaultTextMuted)

        // Стрик
        v.setTextViewText(R.id.large_streak, "🔥${data.streak}d")
        v.setTextColor(R.id.large_streak, mutedColor)

        // X/Y главных
        v.setTextViewText(R.id.large_main_progress, "◓ ${data.mainDone}/${data.mainTotal} main")
        v.setTextColor(R.id.large_main_progress, textColor)

        // Строки расписания (row1..row4)
        val rowData = listOf(
            Triple(R.id.large_row1, R.id.large_time1, R.id.large_icon1) to R.id.large_title1,
            Triple(R.id.large_row2, R.id.large_time2, R.id.large_icon2) to R.id.large_title2,
            Triple(R.id.large_row3, R.id.large_time3, R.id.large_icon3) to R.id.large_title3,
            Triple(R.id.large_row4, R.id.large_time4, R.id.large_icon4) to R.id.large_title4,
        )

        var anyVisible = false
        for ((idx, pair) in rowData.withIndex()) {
            val (ids, titleId) = pair
            val (rowId, timeId, iconId) = ids
            val item = data.nextItems.getOrNull(idx)
            if (item != null) {
                anyVisible = true
                v.setViewVisibility(rowId, View.VISIBLE)
                v.setTextViewText(timeId, item.time)
                v.setTextColor(timeId, textColor)
                v.setTextViewText(iconId, typeIcon(item.type))
                v.setTextColor(iconId, mutedColor)
                v.setTextViewText(titleId, item.title)
                v.setTextColor(titleId, textColor)
                openApp?.let { v.setOnClickPendingIntent(rowId, it) }
            } else {
                v.setViewVisibility(rowId, View.GONE)
            }
        }

        // Пустое состояние
        v.setViewVisibility(R.id.large_empty, if (anyVisible) View.GONE else View.VISIBLE)
        v.setTextColor(R.id.large_empty, mutedColor)

        // Кнопка «+»
        v.setTextColor(R.id.large_add_btn, textColor)
        openApp?.let { v.setOnClickPendingIntent(R.id.large_add_btn, it) }

        // Kai
        applyKai(context, v, R.id.kai_image_large, data)
        openApp?.let { v.setOnClickPendingIntent(R.id.kai_image_large, it) }

        return v
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Вспомогательные функции
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Применяет accent-цвет глаз Kai через ColorFilter.
     * Тело полупрозрачное/тёмное — цвет глаз (белые пиксели) → accent-цвет темы.
     * Ресурс: kai_<emotion>[_harsh] — выбирается по имени через getIdentifier.
     */
    private fun applyKai(context: Context, v: RemoteViews, imageViewId: Int, data: WidgetData) {
        val drawableName = "kai_${data.emotion}" + if (data.isHarsh) "_harsh" else ""
        val resId = context.resources.getIdentifier(drawableName, "drawable", context.packageName)
        if (resId != 0) {
            v.setImageViewResource(imageViewId, resId)
        } else {
            // Фолбэк на нейтральный
            v.setImageViewResource(imageViewId, R.drawable.kai_neutral)
        }

        // Тинтим accent-цветом (глаза белые → accent)
        val accentColor = safeColor(data.themeAccent, defaultAccent)
        v.setInt(imageViewId, "setColorFilter", accentColor)
    }

    /**
     * Применяет цвет фона виджета (theme_surface) через setInt setBackgroundColor.
     * Форма скругления остаётся от widget_bg drawable — меняем только solid-цвет не можем
     * через RemoteViews, поэтому красим background-цвет корневого ViewGroup.
     * NOTE: это закрасит фон поверх drawable; для сохранения скруглений используем
     * setInt с "setBackgroundResource" не подходит — только цвет.
     * Компромисс: фон задаётся через drawable (дефолт Focus), runtime только цвет без скруглений
     * → оставляем drawable widget_bg как есть (дефолт), runtime перекраска через
     * setInt(...setBackgroundColor) — на большинстве лаунчеров будет прямоугольный clip.
     *
     * Более правильный подход для runtime-темизации без потери скруглений:
     * динамически создавать GradientDrawable нельзя из RemoteViews напрямую.
     * Решение: используем fallback — просто ставим theme_surface как backgroundColor.
     * Launcher обычно не клипает по углам сам, форма виджета задаётся системой (API 31+).
     */
    private fun applyBgColor(v: RemoteViews, rootId: Int, data: WidgetData) {
        val surfaceColor = safeColor(data.themeSurface, defaultSurface)
        v.setInt(rootId, "setBackgroundColor", surfaceColor)
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

    // ═══════════════════════════════════════════════════════════════════════════
    // WidgetData — контейнер данных виджета, читается из SharedPreferences
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Данные для одного рендера виджета.
     * Away-логика: если last_opened_at старше 2 дней от now → emotion = "away".
     */
    data class WidgetData(
        val nextItems: List<NextItem>,
        val mainDone: Int,
        val mainTotal: Int,
        val streak: String,
        val emotion: String,         // neutral / success / anxious / away
        val isHarsh: Boolean,
        val themeAccent: String?,
        val themeSurface: String?,
        val themeText: String?,
        val themeTextMuted: String?,
    ) {
        companion object {
            fun from(prefs: android.content.SharedPreferences): WidgetData {
                val nextItemsJson = prefs.getString("next_items", null)
                val nextItems = parseNextItems(nextItemsJson)

                val mainDone = prefs.getInt("main_done", 0)
                val mainTotal = prefs.getInt("main_total", 0)
                val streak = prefs.getString("streak", "0") ?: "0"
                var emotion = prefs.getString("kai_emotion", "neutral") ?: "neutral"
                val isHarsh = prefs.getBoolean("is_harsh", false)
                val lastOpenedAt = prefs.getString("last_opened_at", null)

                // Away-логика: если приложение не открывали ≥ 2 дней → emotion = "away"
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

                return WidgetData(
                    nextItems = nextItems,
                    mainDone = mainDone,
                    mainTotal = mainTotal,
                    streak = streak,
                    emotion = emotion,
                    isHarsh = isHarsh,
                    themeAccent = prefs.getString("theme_accent", null),
                    themeSurface = prefs.getString("theme_surface", null),
                    themeText = prefs.getString("theme_text", null),
                    themeTextMuted = prefs.getString("theme_text_muted", null),
                )
            }

            /**
             * Парсит JSON-массив next_items из SharedPreferences.
             * Формат: [{"time":"14:30","title":"Лекция","type":"event"}]
             */
            private fun parseNextItems(json: String?): List<NextItem> {
                if (json.isNullOrBlank()) return emptyList()
                return try {
                    val arr = JSONArray(json)
                    (0 until minOf(arr.length(), 4)).mapNotNull { i ->
                        val obj = arr.optJSONObject(i) ?: return@mapNotNull null
                        NextItem(
                            time = obj.optString("time", "--:--"),
                            title = obj.optString("title", "—"),
                            type = obj.optString("type", "task"),
                        )
                    }
                } catch (_: JSONException) {
                    emptyList()
                }
            }
        }
    }

    /** Один пункт расписания (ближайшие дела дня). */
    data class NextItem(
        val time: String,
        val title: String,
        val type: String,
    )
}
