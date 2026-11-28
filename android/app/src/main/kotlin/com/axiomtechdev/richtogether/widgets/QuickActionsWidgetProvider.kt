package com.axiomtechdev.richtogether.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.axiomtechdev.richtogether.R
import es.antonborri.home_widget.HomeWidgetProvider

class QuickActionsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val palette = RicherWidgetSupport.resolvePalette(context, widgetData)
        val lblExpense = widgetData.getString("widget_lbl_expense", "Expense") ?: "Expense"
        val lblIncome = widgetData.getString("widget_lbl_income", "Income") ?: "Income"
        val lblTransfer = widgetData.getString("widget_lbl_transfer", "Transfer") ?: "Transfer"

        val expenseIntent = RicherWidgetSupport.launchIntent(context, "expense")
        val incomeIntent = RicherWidgetSupport.launchIntent(context, "income")
        val transferIntent = RicherWidgetSupport.launchIntent(context, "transfer")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_actions).apply {
                setInt(R.id.widget_root, "setBackgroundResource", palette.bgRes)
                setInt(R.id.btn_expense, "setBackgroundResource", palette.pillExpenseRes)
                setInt(R.id.btn_income, "setBackgroundResource", palette.pillIncomeRes)
                setInt(R.id.btn_transfer, "setBackgroundResource", palette.pillTransferRes)

                setTextViewText(R.id.txt_expense, lblExpense)
                setTextViewText(R.id.txt_income, lblIncome)
                setTextViewText(R.id.txt_transfer, lblTransfer)

                setTextColor(R.id.txt_expense, palette.primaryText)
                setTextColor(R.id.txt_income, palette.primaryText)
                setTextColor(R.id.txt_transfer, palette.primaryText)

                setOnClickPendingIntent(R.id.btn_expense, expenseIntent)
                setOnClickPendingIntent(R.id.btn_income, incomeIntent)
                setOnClickPendingIntent(R.id.btn_transfer, transferIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
