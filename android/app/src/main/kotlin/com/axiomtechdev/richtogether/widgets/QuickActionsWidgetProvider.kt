package com.axiomtechdev.richtogether.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import com.axiomtechdev.richtogether.R
import es.antonborri.home_widget.HomeWidgetPlugin
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
            val compact = QuickActionsLayout.isCompact(
                appWidgetManager.getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            )
            val layout = if (compact) R.layout.widget_quick_actions_compact else R.layout.widget_quick_actions

            val views = RemoteViews(context.packageName, layout).apply {
                setInt(R.id.widget_root, "setBackgroundResource", palette.bgRes)
                setInt(R.id.btn_expense, "setBackgroundResource", palette.pillExpenseRes)
                setInt(R.id.btn_income, "setBackgroundResource", palette.pillIncomeRes)
                setInt(R.id.btn_transfer, "setBackgroundResource", palette.pillTransferRes)

                if (compact) {
                    // Icon-only: keep labels for TalkBack.
                    setContentDescription(R.id.btn_expense, lblExpense)
                    setContentDescription(R.id.btn_income, lblIncome)
                    setContentDescription(R.id.btn_transfer, lblTransfer)
                } else {
                    setTextViewText(R.id.txt_expense, lblExpense)
                    setTextViewText(R.id.txt_income, lblIncome)
                    setTextViewText(R.id.txt_transfer, lblTransfer)

                    setTextColor(R.id.txt_expense, palette.primaryText)
                    setTextColor(R.id.txt_income, palette.primaryText)
                    setTextColor(R.id.txt_transfer, palette.primaryText)
                }

                setOnClickPendingIntent(R.id.btn_expense, expenseIntent)
                setOnClickPendingIntent(R.id.btn_income, incomeIntent)
                setOnClickPendingIntent(R.id.btn_transfer, transferIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Re-render with the right layout whenever the user resizes the widget. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    }
}

object QuickActionsLayout {
    /**
     * Below this width (dp) "Expense / Income / Transfer" labels truncate,
     * so the widget switches to icons only. ~3 launcher cells.
     */
    const val COMPACT_MAX_WIDTH_DP = 200

    /** [minWidthDp] 0 means the launcher reported no size yet: use the full layout. */
    fun isCompact(minWidthDp: Int): Boolean = minWidthDp in 1 until COMPACT_MAX_WIDTH_DP
}
