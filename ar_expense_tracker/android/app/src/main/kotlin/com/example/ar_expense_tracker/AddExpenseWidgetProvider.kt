package com.example.ar_expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.graphics.ColorUtils
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AddExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.add_expense_widget).apply {
                    val groupName = widgetData.getString("group_name", "Expense Tracker") ?: "Expense Tracker"
                    val amount = widgetData.getString("amount", "₹0.00") ?: "₹0.00"
                    val dailyAvgRaw = widgetData.getString("daily_avg", "₹0/day") ?: "₹0/day"
                    val dailyAvg = dailyAvgRaw.replace("/day", "").replace(" /day", "")
                    val txCountStr = widgetData.getString("tx_count", "0") ?: "0"
                    val hasBudget = widgetData.getBoolean("has_budget", false)
                    val budgetStatus = widgetData.getString("budget_status", "") ?: ""
                    val budgetPercent = widgetData.getInt("budget_percent", 0)
                    val lastExpense = widgetData.getString("last_expense", "") ?: ""
                    
                    val primaryColor = try {
                        widgetData.getLong("primary_color", 0xFF10B981L).toInt()
                    } catch (e: Exception) {
                        try {
                            widgetData.getInt("primary_color", 0xFF10B981.toInt())
                        } catch (e2: Exception) {
                            0xFF10B981.toInt()
                        }
                    }

                    // 1. Header & Group Info
                    setTextViewText(R.id.widget_group_name, groupName)
                    val txText = if (txCountStr.endsWith("txns") || txCountStr.endsWith("txn")) {
                        txCountStr
                    } else {
                        "$txCountStr ${if (txCountStr == "1") "txn" else "txns"}"
                    }
                    setTextViewText(R.id.widget_tx_count, txText)

                    // 2. Hero Amount
                    setTextViewText(R.id.widget_amount, amount)

                    // 3. Budget Status & Progress Bar (red when over budget)
                    val overBudget = hasBudget && budgetStatus.startsWith("Over")
                    if (hasBudget && budgetStatus.isNotEmpty()) {
                        setViewVisibility(R.id.widget_budget_progress, View.VISIBLE)
                        setProgressBar(R.id.widget_budget_progress, 100, budgetPercent.coerceIn(0, 100), false)
                        setTextViewText(R.id.widget_budget_status, budgetStatus)
                    } else {
                        setViewVisibility(R.id.widget_budget_progress, View.GONE)
                        setTextViewText(R.id.widget_budget_status, "Total spent")
                    }
                    setViewVisibility(R.id.widget_budget_status, View.VISIBLE)

                    // 4. Daily Average
                    val dailyAvgDisplay = (if (dailyAvg.startsWith("₹")) dailyAvg else "₹$dailyAvg") + "/day"
                    setTextViewText(R.id.widget_daily_avg, dailyAvgDisplay)

                    // 5. Recent Expense
                    if (lastExpense.isNotEmpty()) {
                        val parts = lastExpense.split(" • ")
                        if (parts.size >= 3) {
                            setTextViewText(R.id.widget_last_expense_name, parts[0])
                            setTextViewText(R.id.widget_last_expense_amount, parts[1])
                            setTextViewText(R.id.widget_last_expense_date, parts[2])
                            setViewVisibility(R.id.widget_last_expense_date, View.VISIBLE)
                        } else if (parts.size >= 2) {
                            setTextViewText(R.id.widget_last_expense_name, parts[0])
                            setTextViewText(R.id.widget_last_expense_amount, parts[1])
                            setViewVisibility(R.id.widget_last_expense_date, View.GONE)
                        } else {
                            setTextViewText(R.id.widget_last_expense_name, lastExpense)
                            setTextViewText(R.id.widget_last_expense_amount, "")
                            setViewVisibility(R.id.widget_last_expense_date, View.GONE)
                        }
                        setViewVisibility(R.id.widget_last_expense_container, View.VISIBLE)
                        setViewVisibility(R.id.widget_last_expense_empty, View.GONE)
                    } else {
                        setViewVisibility(R.id.widget_last_expense_container, View.GONE)
                        setViewVisibility(R.id.widget_last_expense_empty, View.VISIBLE)
                    }

                    // 6. Theme: every surface, text and icon is toned from the app's seed colour and
                    // follows the app's theme setting (system / light / dark, plus AMOLED black).
                    val themeMode = readInt(widgetData, "theme_mode", 0) // ThemeMode index: 0 system, 1 light, 2 dark
                    val amoled = widgetData.getBoolean("is_amoled", false)
                    val lightTheme = WidgetTheme.from(primaryColor, dark = false, amoled = false)
                    val darkTheme = WidgetTheme.from(primaryColor, dark = true, amoled = amoled)
                    val (day, night) = when (themeMode) {
                        1 -> lightTheme to lightTheme
                        2 -> darkTheme to darkTheme
                        else -> lightTheme to darkTheme
                    }
                    val red = context.getColor(R.color.widget_pro_red)

                    // Raised add button: accent face over a darker lip (same in both themes)
                    val isLightPrimary = ColorUtils.calculateLuminance(primaryColor) > 0.5
                    setInt(R.id.widget_add_face, "setColorFilter", primaryColor)
                    setInt(R.id.widget_add_lip, "setColorFilter", ColorUtils.blendARGB(primaryColor, Color.BLACK, 0.30f))
                    setInt(R.id.widget_add_icon, "setColorFilter", if (isLightPrimary) Color.BLACK else Color.WHITE)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        // Android 12+: day and night values; with "system" the launcher switches itself
                        fun bg(id: Int, pick: (WidgetTheme) -> Int) = setColorStateList(
                            id, "setBackgroundTintList",
                            ColorStateList.valueOf(pick(day)), ColorStateList.valueOf(pick(night))
                        )
                        fun img(id: Int, pick: (WidgetTheme) -> Int) = setColorStateList(
                            id, "setImageTintList",
                            ColorStateList.valueOf(pick(day)), ColorStateList.valueOf(pick(night))
                        )
                        fun text(id: Int, pick: (WidgetTheme) -> Int) =
                            setColorInt(id, "setTextColor", pick(day), pick(night))

                        bg(R.id.widget_root) { it.edge }
                        bg(R.id.widget_root_face) { it.surface }
                        for (id in intArrayOf(R.id.widget_book_chip, R.id.widget_daily_avg_chip, R.id.widget_bottom_right_card)) {
                            bg(id) { it.tileEdge }
                        }
                        for (id in intArrayOf(R.id.widget_book_face, R.id.widget_avg_face, R.id.widget_card_face)) {
                            bg(id) { it.tile }
                        }
                        for (id in intArrayOf(R.id.widget_book_icon, R.id.widget_daily_avg_icon, R.id.widget_recent_icon)) {
                            img(id) { it.icon }
                        }
                        for (id in intArrayOf(
                            R.id.widget_group_name, R.id.widget_amount,
                            R.id.widget_last_expense_name, R.id.widget_last_expense_amount
                        )) text(id) { it.text }
                        for (id in intArrayOf(
                            R.id.widget_tx_count, R.id.widget_latest_label,
                            R.id.widget_last_expense_date, R.id.widget_last_expense_empty
                        )) text(id) { it.textMuted }
                        text(R.id.widget_daily_avg) { it.accentText }
                        if (overBudget) setTextColor(R.id.widget_budget_status, red) else text(R.id.widget_budget_status) { it.textMuted }

                        setColorStateList(
                            R.id.widget_budget_progress, "setProgressTintList",
                            ColorStateList.valueOf(if (overBudget) red else primaryColor)
                        )
                        setColorStateList(
                            R.id.widget_budget_progress, "setProgressBackgroundTintList",
                            ColorStateList.valueOf(day.track), ColorStateList.valueOf(night.track)
                        )
                    } else {
                        // Android 11 and older: tiles keep the neutral resource colours (tinting a
                        // background there drops its rounded corners); text and icons follow the theme.
                        val systemDark = (context.resources.configuration.uiMode and
                            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                            android.content.res.Configuration.UI_MODE_NIGHT_YES
                        val t = if (themeMode == 2 || (themeMode == 0 && systemDark)) darkTheme else lightTheme
                        for (id in intArrayOf(R.id.widget_book_icon, R.id.widget_daily_avg_icon, R.id.widget_recent_icon)) {
                            setInt(id, "setColorFilter", t.icon)
                        }
                        setTextColor(R.id.widget_daily_avg, t.accentText)
                        if (overBudget) setTextColor(R.id.widget_budget_status, red)
                    }

                    val groupId = widgetData.getString("group_id", "") ?: ""

                    // 7. Action Intents with unique request codes
                    val addIntent = Intent(context, MainActivity::class.java).apply {
                        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                        data = Uri.parse("expensetracker://addExpense?groupId=$groupId")
                    }
                    val pendingAddIntent = PendingIntent.getActivity(
                        context,
                        100,
                        addIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val insightsIntent = Intent(context, MainActivity::class.java).apply {
                        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                        data = Uri.parse("expensetracker://insights?groupId=$groupId")
                    }
                    val pendingInsightsIntent = PendingIntent.getActivity(
                        context,
                        101,
                        insightsIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                        data = Uri.parse("expensetracker://open?groupId=$groupId")
                    }
                    val pendingOpenIntent = PendingIntent.getActivity(
                        context,
                        102,
                        openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // Bind touch targets
                    setOnClickPendingIntent(R.id.widget_add_button, pendingAddIntent)
                    setOnClickPendingIntent(R.id.widget_daily_avg_chip, pendingInsightsIntent)
                    setOnClickPendingIntent(R.id.widget_book_chip, pendingOpenIntent)
                    setOnClickPendingIntent(R.id.widget_bottom_right_card, pendingOpenIntent)
                    setOnClickPendingIntent(R.id.widget_root, pendingOpenIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e("ExpenseWidget", "Error updating widget: ${e.message}", e)
            }
        }
    }
}

/** Reads an int that Flutter may have stored as Int or Long. */
private fun readInt(prefs: SharedPreferences, key: String, fallback: Int): Int = try {
    prefs.getInt(key, fallback)
} catch (_: ClassCastException) {
    try { prefs.getLong(key, fallback.toLong()).toInt() } catch (_: Exception) { fallback }
}

/**
 * Widget colours for one theme, toned from the app's seed colour so the widget matches the app:
 * surfaces carry a light wash of the accent, outlines a stronger one, and the daily average and
 * icons use the accent itself (lightened on dark, deepened on light for contrast).
 */
private data class WidgetTheme(
    val edge: Int,
    val surface: Int,
    val tileEdge: Int,
    val tile: Int,
    val track: Int,
    val text: Int,
    val textMuted: Int,
    val accentText: Int,
    val icon: Int
) {
    companion object {
        private fun mix(base: String, primary: Int, amount: Float) =
            ColorUtils.blendARGB(Color.parseColor(base), primary, amount)

        fun from(primary: Int, dark: Boolean, amoled: Boolean): WidgetTheme = when {
            !dark -> WidgetTheme(
                edge = mix("#D7DBE1", primary, 0.22f),
                surface = mix("#F4F5F7", primary, 0.07f),
                tileEdge = mix("#DEE1E7", primary, 0.20f),
                tile = mix("#FFFFFF", primary, 0.035f),
                track = mix("#E4E7EB", primary, 0.15f),
                text = mix("#1B1D21", primary, 0.10f),
                textMuted = mix("#60656D", primary, 0.15f),
                accentText = ColorUtils.blendARGB(primary, Color.BLACK, 0.30f),
                icon = ColorUtils.blendARGB(primary, Color.BLACK, 0.10f)
            )
            amoled -> WidgetTheme(
                edge = mix("#1E2126", primary, 0.25f),
                surface = Color.BLACK,
                tileEdge = mix("#24272C", primary, 0.22f),
                tile = mix("#0D0E10", primary, 0.10f),
                track = mix("#24272C", primary, 0.20f),
                text = Color.parseColor("#ECEDEF"),
                textMuted = mix("#A3A7AE", primary, 0.15f),
                accentText = ColorUtils.blendARGB(primary, Color.WHITE, 0.35f),
                icon = ColorUtils.blendARGB(primary, Color.WHITE, 0.25f)
            )
            else -> WidgetTheme(
                edge = mix("#2A2E34", primary, 0.22f),
                surface = mix("#16181C", primary, 0.08f),
                tileEdge = mix("#2E3238", primary, 0.20f),
                tile = mix("#1F2226", primary, 0.10f),
                track = mix("#2E3238", primary, 0.20f),
                text = Color.parseColor("#E8E9EC"),
                textMuted = mix("#A3A7AE", primary, 0.15f),
                accentText = ColorUtils.blendARGB(primary, Color.WHITE, 0.35f),
                icon = ColorUtils.blendARGB(primary, Color.WHITE, 0.25f)
            )
        }
    }
}
