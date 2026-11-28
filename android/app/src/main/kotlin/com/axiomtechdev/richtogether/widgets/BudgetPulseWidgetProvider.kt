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
        val lblStale = widgetData.getString("widget_lbl_stale", "Open Richer to refresh")
            ?: "Open Richer to refresh"

        // Roll safe/day + days-left forward past midnight using the app's projections.
        val rolled = WidgetRollover.budgetPulse(
            WidgetFreshness.resolve(widgetData),
            hasBudget,
        ) { key -> widgetData.getString(key, null) }
        val isStale = hasBudget && rolled.isStale
        val lblDaysLeft = rolled.daysLeftLbl
        val safeAmountRaw = rolled.safePerDayFmt
        val remainingRaw = widgetData.getString("widget_budget_remaining_fmt", "Rp 0") ?: "Rp 0"

        val headerText = when {
            !hasBudget || isStale -> "Richer"
            status == "over" -> lblOverBudget
            else -> lblSafePerDay
        }
        val heroText = when {
            !hasBudget -> lblNoBudget
            isStale -> lblStale
            status == "over" -> RicherWidgetSupport.maskIfNeeded(widgetData, remainingRaw)
            else -> RicherWidgetSupport.maskIfNeeded(widgetData, safeAmountRaw)
        }
        val showSub = hasBudget && !isStale
        val subText = if (showSub) {
            "$lblBudgetLeft: ${RicherWidgetSupport.maskIfNeeded(widgetData, remainingRaw)}"
        } else {
            ""
        }

        // With no budget yet, every tap target (incl. the gold "+") creates one;
        // otherwise the body opens the Budget tab and "+" logs an expense.
        val budgetIntent = RicherWidgetSupport.launchIntent(
            context,
            if (hasBudget) "budget" else "budget-new",
        )
        val plusIntent = if (hasBudget) {
            RicherWidgetSupport.launchIntent(context, "expense")
        } else {
            budgetIntent
        }
        val plusDescription = if (hasBudget) {
            widgetData.getString("widget_lbl_expense", "Expense") ?: "Expense"
        } else {
            lblNoBudget
        }
        val privacyIntent = RicherWidgetSupport.togglePrivacyIntent(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_budget_pulse).apply {
                setInt(R.id.widget_root, "setBackgroundResource", palette.bgRes)

                setTextViewText(R.id.txt_budget_header, headerText)
                setTextColor(R.id.txt_budget_header, palette.secondaryText)

                setTextViewText(R.id.txt_safe_amount, heroText)
                setTextColor(
                    R.id.txt_safe_amount,
                    if (hasBudget && !isStale && status == "over") palette.errorText else palette.primaryText
                )

                setTextViewText(R.id.txt_budget_sub, subText)
                setTextColor(R.id.txt_budget_sub, palette.secondaryText)
                setViewVisibility(R.id.txt_budget_sub, if (showSub) View.VISIBLE else View.GONE)

                setTextViewText(R.id.txt_days_left, if (showSub) lblDaysLeft else "Richer")
                setTextColor(R.id.txt_days_left, palette.goldText)

                // Eye icon
                setImageViewResource(
                    R.id.btn_privacy,
                    if (isMasked) R.drawable.ic_widget_eye_off else R.drawable.ic_widget_eye
                )
                setInt(R.id.btn_privacy, "setColorFilter", palette.secondaryText)

                // Progress bar state
                val barStatus = if (isStale) "ok" else status
                setViewVisibility(
                    R.id.progress_ok,
                    if (barStatus != "warning" && barStatus != "over") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.progress_warn,
                    if (barStatus == "warning") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.progress_over,
                    if (barStatus == "over") View.VISIBLE else View.GONE
                )
                setProgressBar(R.id.progress_ok, 100, if (showSub) progress else 0, false)
                setProgressBar(R.id.progress_warn, 100, progress, false)
                setProgressBar(R.id.progress_over, 100, progress, false)

                setOnClickPendingIntent(R.id.widget_root, budgetIntent)
                setOnClickPendingIntent(R.id.budget_body_area, budgetIntent)
                setOnClickPendingIntent(R.id.btn_quick_expense, plusIntent)
                setContentDescription(R.id.btn_quick_expense, plusDescription)
                setOnClickPendingIntent(R.id.btn_privacy, privacyIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
