package com.axiomtechdev.richtogether.widgets

import android.content.SharedPreferences
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

/**
 * Decides how a snapshot written by the Flutter app on `snapshotDay` should
 * render on [today] when the app has not refreshed it (e.g. after midnight).
 * Mirrors `WidgetFreshness` in ios/RicherWidgets/RicherWidgets.swift.
 *
 * Native code never formats or computes money: it only picks between values
 * the app pre-formatted (today, zero, or a projected day 1..HORIZON).
 */
data class WidgetFreshness(
    /** Whole calendar days since the snapshot; 0 when fresh or unknown. */
    val dayOffset: Long,
    val isSameMonth: Boolean,
    val isPastBudgetPeriod: Boolean,
) {
    /** A negative offset (clock moved back) is treated as untrustworthy. */
    val budgetIsStale: Boolean
        get() = dayOffset < 0 || dayOffset > HORIZON_DAYS || isPastBudgetPeriod

    companion object {
        const val HORIZON_DAYS = 6

        fun parseDay(raw: String?): LocalDate? {
            if (raw.isNullOrEmpty()) return null
            return try {
                LocalDate.parse(raw)
            } catch (_: DateTimeParseException) {
                null
            }
        }

        fun resolve(snapshotDay: String?, periodEndDay: String?, today: LocalDate): WidgetFreshness {
            // Snapshots from builds before day-tracking existed are assumed fresh.
            val snap = parseDay(snapshotDay)
                ?: return WidgetFreshness(dayOffset = 0, isSameMonth = true, isPastBudgetPeriod = false)
            val end = parseDay(periodEndDay)
            return WidgetFreshness(
                dayOffset = ChronoUnit.DAYS.between(snap, today),
                isSameMonth = snap.year == today.year && snap.monthValue == today.monthValue,
                isPastBudgetPeriod = end != null && today.isAfter(end),
            )
        }

        fun resolve(prefs: SharedPreferences, today: LocalDate = LocalDate.now()): WidgetFreshness =
            resolve(
                prefs.getString("widget_snapshot_day", null),
                prefs.getString("widget_budget_period_end_day", null),
                today,
            )
    }
}

/** Budget Pulse values after applying day rollover. */
data class BudgetPulseValues(
    val safePerDayFmt: String,
    val daysLeftLbl: String,
    val isStale: Boolean,
)

object WidgetRollover {
    /**
     * [lookup] reads a String pref by key (nullable), keeping this testable
     * without Android's SharedPreferences.
     */
    fun budgetPulse(
        freshness: WidgetFreshness,
        hasBudget: Boolean,
        lookup: (String) -> String?,
    ): BudgetPulseValues {
        val safe = lookup("widget_safe_per_day_fmt") ?: "Rp 0"
        val days = lookup("widget_lbl_days_left") ?: ""
        if (!hasBudget || freshness.dayOffset == 0L) return BudgetPulseValues(safe, days, false)
        if (freshness.budgetIsStale) return BudgetPulseValues(safe, days, true)

        val projected = lookup("widget_safe_per_day_fmt_d${freshness.dayOffset}").orEmpty()
        if (projected.isEmpty()) return BudgetPulseValues(safe, days, true)
        val projectedDays = lookup("widget_lbl_days_left_d${freshness.dayOffset}").orEmpty()
        return BudgetPulseValues(projected, projectedDays, false)
    }

    fun todayExpense(freshness: WidgetFreshness, lookup: (String) -> String?): String =
        if (freshness.dayOffset == 0L) {
            lookup("widget_today_expense_fmt") ?: "Rp 0"
        } else {
            zero(lookup)
        }

    fun monthValue(freshness: WidgetFreshness, key: String, lookup: (String) -> String?): String =
        if (freshness.isSameMonth) lookup(key) ?: "Rp 0" else zero(lookup)

    private fun zero(lookup: (String) -> String?): String = lookup("widget_zero_fmt") ?: "Rp 0"
}
