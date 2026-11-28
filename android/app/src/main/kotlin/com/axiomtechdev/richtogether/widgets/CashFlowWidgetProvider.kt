package com.axiomtechdev.richtogether.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.axiomtechdev.richtogether.R
import es.antonborri.home_widget.HomeWidgetProvider

class CashFlowWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val palette = RicherWidgetSupport.resolvePalette(context, widgetData)
        val isMasked = widgetData.getBoolean(RicherWidgetSupport.KEY_MASKED, false)

        val profileName = widgetData.getString("widget_profile_name", "Richer") ?: "Richer"
        val lblToday = widgetData.getString("widget_lbl_today_spend", "Today's Spend") ?: "Today's Spend"
        val lblMonthIn = widgetData.getString("widget_lbl_month_in", "Month In") ?: "Month In"
        val lblMonthOut = widgetData.getString("widget_lbl_month_out", "Month Out") ?: "Month Out"

        // Reset "today" after midnight and month totals after a month change
        // when the app hasn't pushed a fresh snapshot yet.
        val freshness = WidgetFreshness.resolve(widgetData)
        val lookup: (String) -> String? = { key -> widgetData.getString(key, null) }
        val todayRaw = WidgetRollover.todayExpense(freshness, lookup)
        val monthInRaw = WidgetRollover.monthValue(freshness, "widget_month_income_fmt", lookup)
        val monthOutRaw = WidgetRollover.monthValue(freshness, "widget_month_expense_fmt", lookup)

        val todayDisplay = RicherWidgetSupport.maskIfNeeded(widgetData, todayRaw)
        val monthInDisplay = RicherWidgetSupport.maskIfNeeded(widgetData, monthInRaw)
        val monthOutDisplay = RicherWidgetSupport.maskIfNeeded(widgetData, monthOutRaw)

        val overviewIntent = RicherWidgetSupport.launchIntent(context, "overview")
        val quickExpenseIntent = RicherWidgetSupport.launchIntent(context, "expense")
        val privacyIntent = RicherWidgetSupport.togglePrivacyIntent(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_cash_flow).apply {
                setInt(R.id.widget_root, "setBackgroundResource", palette.bgRes)
                setInt(R.id.pill_month_in, "setBackgroundResource", palette.pillIncomeRes)
                setInt(R.id.pill_month_out, "setBackgroundResource", palette.pillExpenseRes)

                setTextViewText(R.id.txt_profile_today, "$profileName • $lblToday")
                setTextColor(R.id.txt_profile_today, palette.goldText)

                setTextViewText(R.id.txt_today_amount, todayDisplay)
                setTextColor(R.id.txt_today_amount, palette.primaryText)

                setTextViewText(R.id.txt_lbl_month_in, lblMonthIn)
                setTextColor(R.id.txt_lbl_month_in, palette.secondaryText)
                setTextViewText(R.id.txt_val_month_in, monthInDisplay)
                setTextColor(R.id.txt_val_month_in, palette.successText)

                setTextViewText(R.id.txt_lbl_month_out, lblMonthOut)
                setTextColor(R.id.txt_lbl_month_out, palette.secondaryText)
                setTextViewText(R.id.txt_val_month_out, monthOutDisplay)
                setTextColor(R.id.txt_val_month_out, palette.errorText)

                setImageViewResource(
                    R.id.btn_privacy,
                    if (isMasked) R.drawable.ic_widget_eye_off else R.drawable.ic_widget_eye
                )
                setInt(R.id.btn_privacy, "setColorFilter", palette.secondaryText)

                setOnClickPendingIntent(R.id.widget_root, overviewIntent)
                setOnClickPendingIntent(R.id.cashflow_header_area, overviewIntent)
                setOnClickPendingIntent(R.id.cashflow_bottom_row, overviewIntent)
                setOnClickPendingIntent(R.id.btn_quick_expense, quickExpenseIntent)
                setOnClickPendingIntent(R.id.btn_privacy, privacyIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
