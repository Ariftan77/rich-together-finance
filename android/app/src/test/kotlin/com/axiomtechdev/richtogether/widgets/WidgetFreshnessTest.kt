package com.axiomtechdev.richtogether.widgets

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetFreshnessTest {

    private val prefs = mapOf(
        "widget_today_expense_fmt" to "Rp 85.000",
        "widget_month_income_fmt" to "Rp 8.500.000",
        "widget_month_expense_fmt" to "Rp 1.600.000",
        "widget_zero_fmt" to "Rp 0",
        "widget_safe_per_day_fmt" to "Rp 200.000",
        "widget_lbl_days_left" to "12 days left",
        "widget_safe_per_day_fmt_d1" to "Rp 218.182",
        "widget_lbl_days_left_d1" to "11 days left",
        "widget_safe_per_day_fmt_d2" to "",
        "widget_lbl_days_left_d2" to "",
    )
    private val lookup: (String) -> String? = { prefs[it] }

    @Test
    fun `given snapshot from today when resolving then nothing rolls over`() {
        val f = WidgetFreshness.resolve("2026-11-28", "2026-11-30", LocalDate.of(2026, 11, 28))

        assertEquals(0L, f.dayOffset)
        assertEquals("Rp 85.000", WidgetRollover.todayExpense(f, lookup))
        val pulse = WidgetRollover.budgetPulse(f, hasBudget = true, lookup = lookup)
        assertEquals("Rp 200.000", pulse.safePerDayFmt)
        assertFalse(pulse.isStale)
    }

    @Test
    fun `given snapshot from yesterday when resolving then today resets and day 1 projection is used`() {
        val f = WidgetFreshness.resolve("2026-11-28", "2026-11-30", LocalDate.of(2026, 11, 29))

        assertEquals(1L, f.dayOffset)
        assertEquals("Rp 0", WidgetRollover.todayExpense(f, lookup))
        assertEquals("Rp 8.500.000", WidgetRollover.monthValue(f, "widget_month_income_fmt", lookup))
        val pulse = WidgetRollover.budgetPulse(f, hasBudget = true, lookup = lookup)
        assertEquals("Rp 218.182", pulse.safePerDayFmt)
        assertEquals("11 days left", pulse.daysLeftLbl)
        assertFalse(pulse.isStale)
    }

    @Test
    fun `given empty projection slot when resolving then budget is stale`() {
        val f = WidgetFreshness.resolve("2026-11-28", "2026-12-31", LocalDate.of(2026, 11, 30))

        assertTrue(WidgetRollover.budgetPulse(f, hasBudget = true, lookup = lookup).isStale)
    }

    @Test
    fun `given month boundary crossed when resolving then month totals reset and budget is stale`() {
        val f = WidgetFreshness.resolve("2026-11-30", "2026-11-30", LocalDate.of(2026, 12, 1))

        assertFalse(f.isSameMonth)
        assertTrue(f.isPastBudgetPeriod)
        assertEquals("Rp 0", WidgetRollover.monthValue(f, "widget_month_expense_fmt", lookup))
        assertTrue(WidgetRollover.budgetPulse(f, hasBudget = true, lookup = lookup).isStale)
    }

    @Test
    fun `given snapshot older than horizon when resolving then budget is stale`() {
        val f = WidgetFreshness.resolve("2026-01-01", "2026-12-31", LocalDate.of(2026, 1, 8))

        assertEquals(7L, f.dayOffset)
        assertTrue(f.budgetIsStale)
    }

    @Test
    fun `given clock moved back when resolving then budget is stale and today resets`() {
        val f = WidgetFreshness.resolve("2026-11-28", "2026-11-30", LocalDate.of(2026, 11, 27))

        assertTrue(f.budgetIsStale)
        assertEquals("Rp 0", WidgetRollover.todayExpense(f, lookup))
    }

    @Test
    fun `given legacy snapshot without day when resolving then treated as fresh`() {
        val f = WidgetFreshness.resolve(null, null, LocalDate.of(2026, 11, 28))

        assertEquals(0L, f.dayOffset)
        assertTrue(f.isSameMonth)
        assertFalse(f.budgetIsStale)
    }

    @Test
    fun `given malformed day when resolving then treated as fresh`() {
        val f = WidgetFreshness.resolve("28/11/2026", "", LocalDate.of(2026, 11, 28))

        assertEquals(0L, f.dayOffset)
    }

    @Test
    fun `given no budget when rolling over then never stale`() {
        val f = WidgetFreshness.resolve("2026-11-01", "", LocalDate.of(2026, 11, 28))

        assertFalse(WidgetRollover.budgetPulse(f, hasBudget = false, lookup = lookup).isStale)
    }
}

class QuickActionsLayoutTest {
    @Test
    fun `given narrow widget when choosing layout then compact`() {
        assertTrue(QuickActionsLayout.isCompact(110))
        assertTrue(QuickActionsLayout.isCompact(199))
    }

    @Test
    fun `given wide or unknown widget when choosing layout then full`() {
        assertFalse(QuickActionsLayout.isCompact(200))
        assertFalse(QuickActionsLayout.isCompact(320))
        assertFalse(QuickActionsLayout.isCompact(0))
    }
}
