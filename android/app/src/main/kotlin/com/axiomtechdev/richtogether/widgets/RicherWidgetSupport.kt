package com.axiomtechdev.richtogether.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import com.axiomtechdev.richtogether.MainActivity
import com.axiomtechdev.richtogether.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

data class WidgetPalette(
    val isLight: Boolean,
    val bgRes: Int,
    val pillExpenseRes: Int,
    val pillIncomeRes: Int,
    val pillTransferRes: Int,
    val primaryText: Int,
    val secondaryText: Int,
    val goldText: Int,
    val successText: Int,
    val errorText: Int,
)

object RicherWidgetSupport {
    const val ACTION_TOGGLE_PRIVACY = "com.axiomtechdev.richtogether.ACTION_TOGGLE_WIDGET_PRIVACY"
    const val KEY_MASKED = "widget_amounts_masked"

    fun resolvePalette(context: Context, prefs: SharedPreferences): WidgetPalette {
        val mode = prefs.getString("widget_theme_mode", "default") ?: "default"
        val systemNight =
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES

        val useLight = mode == "light" || (mode == "system" && !systemNight)
        val useAmoledDark = mode == "dark" || (mode == "system" && systemNight)

        return if (useLight) {
            WidgetPalette(
                isLight = true,
                bgRes = R.drawable.widget_bg_light,
                pillExpenseRes = R.drawable.widget_pill_expense_light,
                pillIncomeRes = R.drawable.widget_pill_income_light,
                pillTransferRes = R.drawable.widget_pill_transfer_light,
                primaryText = 0xFF1E293B.toInt(),
                secondaryText = 0xFF64748B.toInt(),
                goldText = 0xFFB8962E.toInt(),
                successText = 0xFF16A34A.toInt(),
                errorText = 0xFFDC2626.toInt(),
            )
        } else {
            WidgetPalette(
                isLight = false,
                bgRes = if (useAmoledDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_default,
                pillExpenseRes = R.drawable.widget_pill_expense_dark,
                pillIncomeRes = R.drawable.widget_pill_income_dark,
                pillTransferRes = R.drawable.widget_pill_transfer_dark,
                primaryText = 0xFFFFFFFF.toInt(),
                secondaryText = 0xB3FFFFFF.toInt(),
                goldText = 0xFFD4AF37.toInt(),
                successText = 0xFF2ECC71.toInt(),
                errorText = 0xFFE74C3C.toInt(),
            )
        }
    }

    fun launchIntent(context: Context, actionSegment: String): PendingIntent {
        val uri = Uri.parse("richtogether://widget/$actionSegment?homeWidget=1")
        return HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
    }

    fun togglePrivacyIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetPrivacyReceiver::class.java).apply {
            action = ACTION_TOGGLE_PRIVACY
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, 901, intent, flags)
    }

    fun maskIfNeeded(prefs: SharedPreferences, rawValue: String): String {
        val masked = prefs.getBoolean(KEY_MASKED, false)
        if (!masked) return rawValue
        return prefs.getString("widget_masked_placeholder", "Rp ••••••") ?: "••••••"
    }
}

/**
 * Toggles amount masking directly in SharedPreferences without spinning up a
 * background Flutter engine, making privacy toggling instantaneous and offline-safe.
 */
class WidgetPrivacyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RicherWidgetSupport.ACTION_TOGGLE_PRIVACY) return

        val prefs = HomeWidgetPlugin.getData(context)
        val current = prefs.getBoolean(RicherWidgetSupport.KEY_MASKED, false)
        prefs.edit().putBoolean(RicherWidgetSupport.KEY_MASKED, !current).apply()

        val manager = AppWidgetManager.getInstance(context)

        val budgetIds = manager.getAppWidgetIds(
            ComponentName(context, BudgetPulseWidgetProvider::class.java)
        )
        if (budgetIds.isNotEmpty()) {
            BudgetPulseWidgetProvider().onUpdate(context, manager, budgetIds, prefs)
        }

        val cashFlowIds = manager.getAppWidgetIds(
            ComponentName(context, CashFlowWidgetProvider::class.java)
        )
        if (cashFlowIds.isNotEmpty()) {
            CashFlowWidgetProvider().onUpdate(context, manager, cashFlowIds, prefs)
        }
    }
}
