package com.axiomtechdev.richtogether.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.axiomtechdev.richtogether.R
import es.antonborri.home_widget.HomeWidgetProvider

class BudgetPulseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val palette = RicherWidgetSupport.resolvePalette(context, widgetData)
        val isMasked = widgetData.getBoolean(RicherWidgetSupport.KEY_MASKED, false)
        val hasBudget = widgetData.getBoolean("widget_has_budget", false)
        val status = widgetData.getString("widget_budget_status", "ok") ?: "ok"
        val progress = widgetData.getInt("widget_budget_progress_pct", 0).coerceIn(0, 100)

        val lblSafePerDay = widgetData.getString("widget_lbl_safe_per_day", "Safe / day") ?: "Safe / day"
        val lblBudgetLeft = widgetData.getString("widget_lbl_budget_left", "Budget left") ?: "Budget left"
        val lblOverBudget = widgetData.getString("widget_lbl_over_budget", "Over budget") ?: "Over budget"
        val lblNoBudget = widgetData.getString("widget_lbl_no_budget", "Tap to set budget") ?: "Tap to set budget"
        val lblDaysLeft = widgetData.getString("widget_lbl_days_left", "") ?: ""

        val safeAmountRaw = widgetData.getString("widget_safe_per_day_fmt", "Rp 0") ?: "Rp 0"
        val remainingRaw = widgetData.getString("widget_budget_remaining_fmt", "Rp 0") ?: "Rp 0"

        val headerText = when {
            !hasBudget -> "Richer"
            status == "over" -> lblOverBudget
            else -> lblSafePerDay
        }
        val heroText = when {
            !hasBudget -> lblNoBudget
            status == "over" -> RicherWidgetSupport.maskIfNeeded(widgetData, remainingRaw)
            else -> RicherWidgetSupport.maskIfNeeded(widgetData, safeAmountRaw)
        }
        val subText = if (hasBudget) {
            "$lblBudgetLeft: ${RicherWidgetSupport.maskIfNeeded(widgetData, remainingRaw)}"
        } else {
            ""
        }

        val budgetIntent = RicherWidgetSupport.launchIntent(context, "budget")
        val quickExpenseIntent = RicherWidgetSupport.launchIntent(context, "expense")
        val privacyIntent = RicherWidgetSupport.togglePrivacyIntent(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_budget_pulse).apply {
                setInt(R.id.widget_root, "setBackgroundResource", palette.bgRes)

                setTextViewText(R.id.txt_budget_header, headerText)
                setTextColor(R.id.txt_budget_header, palette.secondaryText)

                setTextViewText(R.id.txt_safe_amount, heroText)
                setTextColor(
                    R.id.txt_safe_amount,
                    if (hasBudget && status == "over") palette.errorText else palette.primaryText
                )

                setTextViewText(R.id.txt_budget_sub, subText)
                setTextColor(R.id.txt_budget_sub, palette.secondaryText)
                setViewVisibility(R.id.txt_budget_sub, if (hasBudget) View.VISIBLE else View.GONE)

                setTextViewText(R.id.txt_days_left, if (hasBudget) lblDaysLeft else "Richer")
                setTextColor(R.id.txt_days_left, palette.goldText)

                // Eye icon
                setImageViewResource(
                    R.id.btn_privacy,
                    if (isMasked) R.drawable.ic_widget_eye_off else R.drawable.ic_widget_eye
                )
                setInt(R.id.btn_privacy, "setColorFilter", palette.secondaryText)

                // Progress bar state
                setViewVisibility(
                    R.id.progress_ok,
                    if (status != "warning" && status != "over") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.progress_warn,
                    if (status == "warning") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.progress_over,
                    if (status == "over") View.VISIBLE else View.GONE
                )
                setProgressBar(R.id.progress_ok, 100, if (hasBudget) progress else 0, false)
                setProgressBar(R.id.progress_warn, 100, progress, false)
                setProgressBar(R.id.progress_over, 100, progress, false)

                setOnClickPendingIntent(R.id.widget_root, budgetIntent)
                setOnClickPendingIntent(R.id.budget_body_area, budgetIntent)
                setOnClickPendingIntent(R.id.btn_quick_expense, quickExpenseIntent)
                setOnClickPendingIntent(R.id.btn_privacy, privacyIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
