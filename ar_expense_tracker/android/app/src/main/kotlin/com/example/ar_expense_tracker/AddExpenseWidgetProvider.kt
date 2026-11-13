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

                    // 3. Budget Status & Progress Bar
                    if (hasBudget && budgetStatus.isNotEmpty()) {
                        setViewVisibility(R.id.widget_budget_progress, View.VISIBLE)
                        setProgressBar(R.id.widget_budget_progress, 100, budgetPercent.coerceIn(0, 100), false)
                        setTextViewText(R.id.widget_budget_status, budgetStatus)
                        setViewVisibility(R.id.widget_budget_status, View.VISIBLE)
                    } else {
                        setViewVisibility(R.id.widget_budget_progress, View.GONE)
                        setTextViewText(R.id.widget_budget_status, "Total spent")
                        setViewVisibility(R.id.widget_budget_status, View.VISIBLE)
                    }

                    // 4. Daily Average
                    val dailyAvgDisplay = if (dailyAvg.startsWith("₹")) "Avg: $dailyAvg" else "Avg: ₹$dailyAvg"
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

                    // 6. Dynamic Material You Tonal Theme Blending
                    val isDarkTheme = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
                    val isLightPrimary = ColorUtils.calculateLuminance(primaryColor) > 0.5
                    val primaryButtonTextColor = if (isLightPrimary) Color.BLACK else Color.WHITE

                    val baseSurfaceColor = if (isDarkTheme) Color.parseColor("#121316") else Color.parseColor("#F4F5F9")
                    val baseCardColor = if (isDarkTheme) Color.parseColor("#1A1C1F") else Color.parseColor("#FFFFFF")
                    val basePillColor = if (isDarkTheme) Color.parseColor("#24262A") else Color.parseColor("#E8EAF0")

                    val rootBgTint = ColorUtils.blendARGB(baseSurfaceColor, primaryColor, if (isDarkTheme) 0.10f else 0.06f)
                    val cardBgTint = ColorUtils.blendARGB(baseCardColor, primaryColor, if (isDarkTheme) 0.16f else 0.10f)
                    val pillBgTint = ColorUtils.blendARGB(basePillColor, primaryColor, if (isDarkTheme) 0.22f else 0.12f)
                    val iconTint = ColorUtils.blendARGB(if (isDarkTheme) Color.WHITE else Color.BLACK, primaryColor, 0.45f)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        // Tint container backgrounds
                        setColorStateList(R.id.widget_root, "setBackgroundTintList", ColorStateList.valueOf(rootBgTint))
                        setColorStateList(R.id.widget_book_chip, "setBackgroundTintList", ColorStateList.valueOf(pillBgTint))
                        setColorStateList(R.id.widget_daily_avg_chip, "setBackgroundTintList", ColorStateList.valueOf(pillBgTint))
                        setColorStateList(R.id.widget_tx_chip, "setBackgroundTintList", ColorStateList.valueOf(pillBgTint))
                        setColorStateList(R.id.widget_bottom_right_card, "setBackgroundTintList", ColorStateList.valueOf(pillBgTint))
                        
                        // Tint icons
                        setColorStateList(R.id.widget_book_icon, "setImageTintList", ColorStateList.valueOf(iconTint))
                        setColorStateList(R.id.widget_daily_avg_icon, "setImageTintList", ColorStateList.valueOf(iconTint))
                        setColorStateList(R.id.widget_recent_icon, "setImageTintList", ColorStateList.valueOf(iconTint))

                        // Tint Quick Add FAB
                        setColorStateList(R.id.widget_fallback_fab, "setBackgroundTintList", ColorStateList.valueOf(primaryColor))
                        setColorStateList(R.id.widget_fallback_icon, "setImageTintList", ColorStateList.valueOf(primaryButtonTextColor))

                        // Tint progress bar
                        setColorStateList(R.id.widget_budget_progress, "setProgressTintList", ColorStateList.valueOf(primaryColor))
                    } else {
                        setInt(R.id.widget_fallback_fab, "setBackgroundColor", primaryColor)
                        setInt(R.id.widget_fallback_icon, "setColorFilter", primaryButtonTextColor)
                    }

                    // Apply contrast-matched text colors
                    val amountColor = if (isDarkTheme) {
                        ColorUtils.blendARGB(primaryColor, Color.WHITE, 0.85f)
                    } else {
                        ColorUtils.blendARGB(primaryColor, Color.BLACK, 0.85f)
                    }
                    val statNumberColor = if (isDarkTheme) {
                        ColorUtils.blendARGB(primaryColor, Color.WHITE, 0.70f)
                    } else {
                        ColorUtils.blendARGB(primaryColor, Color.BLACK, 0.70f)
                    }

                    setTextColor(R.id.widget_amount, amountColor)
                    setTextColor(R.id.widget_daily_avg, statNumberColor)
                    setTextColor(R.id.widget_last_expense_amount, statNumberColor)

                    // 7. Dynamic FAB Bitmap matching custom shape
                    val bitmapPath = widgetData.getString("fab_icon_bitmap", null)
                    if (bitmapPath != null && java.io.File(bitmapPath).exists()) {
                        val bitmap = android.graphics.BitmapFactory.decodeFile(bitmapPath)
                        if (bitmap != null) {
                            setImageViewBitmap(R.id.widget_bitmap_fab, bitmap)
                            setViewVisibility(R.id.widget_bitmap_fab, View.VISIBLE)
                            setViewVisibility(R.id.widget_fallback_fab, View.GONE)
                        } else {
                            setViewVisibility(R.id.widget_bitmap_fab, View.GONE)
                            setViewVisibility(R.id.widget_fallback_fab, View.VISIBLE)
                        }
                    } else {
                        setViewVisibility(R.id.widget_bitmap_fab, View.GONE)
                        setViewVisibility(R.id.widget_fallback_fab, View.VISIBLE)
                    }

                    val groupId = widgetData.getString("group_id", "") ?: ""

                    // 8. Action Intents with unique request codes
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
                    setOnClickPendingIntent(R.id.widget_tx_chip, pendingOpenIntent)
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
