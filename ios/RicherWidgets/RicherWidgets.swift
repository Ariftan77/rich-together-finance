import AppIntents
import SwiftUI
import WidgetKit

private let richerAppGroupId = "group.com.axiomtechdev.richtogether"
private let privacyMaskKey = "widget_amounts_masked"
private let projectionHorizonDays = 6

// MARK: - Day Rollover

/// Parses the `yyyy-MM-dd` local-day strings written by the Flutter app.
func parseWidgetDay(_ raw: String?, calendar: Calendar) -> Date? {
  guard let raw = raw, !raw.isEmpty else { return nil }
  let parts = raw.split(separator: "-").compactMap { Int($0) }
  guard parts.count == 3 else { return nil }
  return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

/// Decides how a snapshot taken on `snapshotDay` should render on `now`,
/// without the app having refreshed it. Mirrors `WidgetFreshness.kt`.
struct WidgetFreshness {
  /// Whole calendar days since the snapshot; 0 when the snapshot is from today
  /// (or when no snapshot day was recorded by an older app build).
  let dayOffset: Int
  let isSameMonth: Bool
  let isPastBudgetPeriod: Bool

  static func resolve(
    snapshotDay: String?,
    periodEndDay: String?,
    now: Date,
    calendar: Calendar = .current
  ) -> WidgetFreshness {
    let today = calendar.startOfDay(for: now)
    guard let snap = parseWidgetDay(snapshotDay, calendar: calendar) else {
      return WidgetFreshness(dayOffset: 0, isSameMonth: true, isPastBudgetPeriod: false)
    }
    let offset = calendar.dateComponents([.day], from: snap, to: today).day ?? 0
    let sameMonth =
      calendar.component(.year, from: snap) == calendar.component(.year, from: today)
      && calendar.component(.month, from: snap) == calendar.component(.month, from: today)
    var pastPeriod = false
    if let end = parseWidgetDay(periodEndDay, calendar: calendar) {
      pastPeriod = today > end
    }
    return WidgetFreshness(dayOffset: offset, isSameMonth: sameMonth, isPastBudgetPeriod: pastPeriod)
  }

  /// A budget projection exists only for days 1...horizon inside the period.
  /// A negative offset (clock moved back) is treated as untrustworthy.
  var budgetIsStale: Bool {
    dayOffset < 0 || dayOffset > projectionHorizonDays || isPastBudgetPeriod
  }
}

// MARK: - Shared Data Model

struct RicherWidgetEntry: TimelineEntry {
  let date: Date
  let profileName: String
  let themeMode: String
  let isMasked: Bool
  let maskedPlaceholder: String

  let lblExpense: String
  let lblIncome: String
  let lblTransfer: String
  let lblSafePerDay: String
  let lblBudgetLeft: String
  let lblOverBudget: String
  let lblNoBudget: String
  let lblDaysLeft: String
  let lblTodaySpend: String
  let lblMonthIn: String
  let lblMonthOut: String
  let lblStale: String
  let isBudgetStale: Bool

  let hasBudget: Bool
  let budgetRemainingFmt: String
  let safePerDayFmt: String
  let budgetProgressPct: Int
  let budgetStatus: String

  let todayExpenseFmt: String
  let monthExpenseFmt: String
  let monthIncomeFmt: String

  func display(_ raw: String) -> String {
    return isMasked ? maskedPlaceholder : raw
  }

  static func load(isPreview: Bool, at date: Date = Date()) -> RicherWidgetEntry {
    let prefs = UserDefaults(suiteName: richerAppGroupId)
    let hasData = prefs?.bool(forKey: "widget_has_data") ?? false

    if isPreview && !hasData {
      return RicherWidgetEntry(
        date: date,
        profileName: "Personal",
        themeMode: "default",
        isMasked: false,
        maskedPlaceholder: "Rp ••••••",
        lblExpense: "Expense",
        lblIncome: "Income",
        lblTransfer: "Transfer",
        lblSafePerDay: "Safe / day",
        lblBudgetLeft: "Budget left",
        lblOverBudget: "Over budget",
        lblNoBudget: "Tap to set budget",
        lblDaysLeft: "12 days left",
        lblTodaySpend: "Today's Spend",
        lblMonthIn: "Month In",
        lblMonthOut: "Month Out",
        lblStale: "Open Richer to refresh",
        isBudgetStale: false,
        hasBudget: true,
        budgetRemainingFmt: "Rp 2.400.000",
        safePerDayFmt: "Rp 200.000",
        budgetProgressPct: 45,
        budgetStatus: "ok",
        todayExpenseFmt: "Rp 85.000",
        monthExpenseFmt: "Rp 1.600.000",
        monthIncomeFmt: "Rp 8.500.000"
      )
    }

    func str(_ key: String, _ fallback: String) -> String {
      prefs?.string(forKey: key) ?? fallback
    }

    let freshness = WidgetFreshness.resolve(
      snapshotDay: prefs?.string(forKey: "widget_snapshot_day"),
      periodEndDay: prefs?.string(forKey: "widget_budget_period_end_day"),
      now: date
    )
    let zero = str("widget_zero_fmt", "Rp 0")
    let hasBudget = prefs?.bool(forKey: "widget_has_budget") ?? false

    // Budget Pulse: roll safe/day + days-left forward using the app's
    // pre-computed projections; never invent numbers natively.
    var safePerDay = str("widget_safe_per_day_fmt", "Rp 0")
    var daysLeft = str("widget_lbl_days_left", "")
    var budgetStale = false
    if hasBudget && freshness.dayOffset != 0 {
      if freshness.budgetIsStale {
        budgetStale = true
      } else {
        let projected = str("widget_safe_per_day_fmt_d\(freshness.dayOffset)", "")
        let projectedDays = str("widget_lbl_days_left_d\(freshness.dayOffset)", "")
        if projected.isEmpty {
          budgetStale = true
        } else {
          safePerDay = projected
          daysLeft = projectedDays
        }
      }
    }

    return RicherWidgetEntry(
      date: date,
      profileName: prefs?.string(forKey: "widget_profile_name") ?? "Richer",
      themeMode: prefs?.string(forKey: "widget_theme_mode") ?? "default",
      isMasked: prefs?.bool(forKey: privacyMaskKey) ?? false,
      maskedPlaceholder: prefs?.string(forKey: "widget_masked_placeholder") ?? "Rp ••••••",
      lblExpense: prefs?.string(forKey: "widget_lbl_expense") ?? "Expense",
      lblIncome: prefs?.string(forKey: "widget_lbl_income") ?? "Income",
      lblTransfer: prefs?.string(forKey: "widget_lbl_transfer") ?? "Transfer",
      lblSafePerDay: prefs?.string(forKey: "widget_lbl_safe_per_day") ?? "Safe / day",
      lblBudgetLeft: prefs?.string(forKey: "widget_lbl_budget_left") ?? "Budget left",
      lblOverBudget: prefs?.string(forKey: "widget_lbl_over_budget") ?? "Over budget",
      lblNoBudget: prefs?.string(forKey: "widget_lbl_no_budget") ?? "Tap to set budget",
      lblDaysLeft: daysLeft,
      lblTodaySpend: prefs?.string(forKey: "widget_lbl_today_spend") ?? "Today's Spend",
      lblMonthIn: prefs?.string(forKey: "widget_lbl_month_in") ?? "Month In",
      lblMonthOut: prefs?.string(forKey: "widget_lbl_month_out") ?? "Month Out",
      lblStale: str("widget_lbl_stale", "Open Richer to refresh"),
      isBudgetStale: budgetStale,
      hasBudget: hasBudget,
      budgetRemainingFmt: prefs?.string(forKey: "widget_budget_remaining_fmt") ?? "Rp 0",
      safePerDayFmt: safePerDay,
      budgetProgressPct: prefs?.integer(forKey: "widget_budget_progress_pct") ?? 0,
      budgetStatus: prefs?.string(forKey: "widget_budget_status") ?? "ok",
      todayExpenseFmt: freshness.dayOffset == 0
        ? str("widget_today_expense_fmt", "Rp 0") : zero,
      monthExpenseFmt: freshness.isSameMonth
        ? str("widget_month_expense_fmt", "Rp 0") : zero,
      monthIncomeFmt: freshness.isSameMonth
        ? str("widget_month_income_fmt", "Rp 0") : zero
    )
  }
}

struct RicherTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> RicherWidgetEntry {
    RicherWidgetEntry.load(isPreview: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (RicherWidgetEntry) -> Void) {
    completion(RicherWidgetEntry.load(isPreview: context.isPreview))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RicherWidgetEntry>) -> Void) {
    // One entry now plus one at each upcoming local midnight, so "today" resets
    // and safe/day rolls forward even if the app is never opened. The app calls
    // reloadAllTimelines whenever data changes, which rebuilds this timeline.
    let calendar = Calendar.current
    let now = Date()
    var entries = [RicherWidgetEntry.load(isPreview: false, at: now)]
    var midnight = calendar.startOfDay(for: now)
    for _ in 0...projectionHorizonDays {
      guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
      midnight = next
      entries.append(RicherWidgetEntry.load(isPreview: false, at: midnight))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Interactive Privacy Intent (iOS 17+)

@available(iOS 17.0, *)
struct ToggleWidgetPrivacyIntent: AppIntent {
  static var title: LocalizedStringResource = "Toggle Amount Privacy"
  static var description = IntentDescription("Masks or unmasks financial amounts on Richer widgets.")

  func perform() async throws -> some IntentResult {
    if let prefs = UserDefaults(suiteName: richerAppGroupId) {
      let current = prefs.bool(forKey: privacyMaskKey)
      prefs.set(!current, forKey: privacyMaskKey)
    }
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

// MARK: - Theme Palette & Helpers

struct RicherPalette {
  let isLight: Bool
  let background: LinearGradient
  let primaryText: Color
  let secondaryText: Color
  let gold: Color
  let success: Color
  let error: Color
  let warning: Color

  static func resolve(themeMode: String, systemScheme: ColorScheme) -> RicherPalette {
    let useLight = themeMode == "light" || (themeMode == "system" && systemScheme == .light)
    let useAmoled = themeMode == "dark" || (themeMode == "system" && systemScheme == .dark)

    if useLight {
      return RicherPalette(
        isLight: true,
        background: LinearGradient(
          colors: [
            Color(red: 0.973, green: 0.980, blue: 0.988),
            Color(red: 1.000, green: 0.984, blue: 0.922),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        primaryText: Color(red: 0.118, green: 0.161, blue: 0.231),
        secondaryText: Color(red: 0.392, green: 0.455, blue: 0.545),
        gold: Color(red: 0.722, green: 0.588, blue: 0.180),
        success: Color(red: 0.086, green: 0.639, blue: 0.290),
        error: Color(red: 0.863, green: 0.149, blue: 0.149),
        warning: Color(red: 0.851, green: 0.467, blue: 0.024)
      )
    }

    let bg = useAmoled
      ? LinearGradient(
          colors: [
            Color(red: 0.05, green: 0.05, blue: 0.05),
            Color(red: 0.10, green: 0.10, blue: 0.10),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      : LinearGradient(
          colors: [
            Color(red: 0.122, green: 0.231, blue: 0.380),
            Color(red: 0.078, green: 0.133, blue: 0.220),
            Color(red: 0.227, green: 0.180, blue: 0.078),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

    return RicherPalette(
      isLight: false,
      background: bg,
      primaryText: .white,
      secondaryText: Color.white.opacity(0.72),
      gold: Color(red: 0.831, green: 0.686, blue: 0.216),
      success: Color(red: 0.180, green: 0.800, blue: 0.443),
      error: Color(red: 0.906, green: 0.298, blue: 0.235),
      warning: Color(red: 0.945, green: 0.769, blue: 0.059)
    )
  }
}

private func widgetDeepLink(_ segment: String) -> URL {
  URL(string: "richtogether://widget/\(segment)?homeWidget=1")!
}

extension View {
  @ViewBuilder
  func richerWidgetContainer(_ background: LinearGradient) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) {
        background
      }
    } else {
      self.padding(14).background(background)
    }
  }
}

@ViewBuilder
private func privacyToggleControl(isMasked: Bool, color: Color) -> some View {
  let iconName = isMasked ? "eye.slash.fill" : "eye.fill"
  if #available(iOSApplicationExtension 17.0, *) {
    Button(intent: ToggleWidgetPrivacyIntent()) {
      Image(systemName: iconName)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(color)
        .frame(width: 26, height: 26)
    }
    .buttonStyle(.plain)
  } else {
    Link(destination: widgetDeepLink("toggle-privacy")) {
      Image(systemName: iconName)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(color)
        .frame(width: 26, height: 26)
    }
  }
}

@ViewBuilder
private func quickExpenseBadge(destination: URL = widgetDeepLink("expense")) -> some View {
  Link(destination: destination) {
    Image(systemName: "plus")
      .font(.system(size: 13, weight: .bold))
      .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
      .frame(width: 26, height: 26)
      .background(Circle().fill(Color(red: 0.831, green: 0.686, blue: 0.216)))
  }
}

// MARK: - Widget 1: Quick Actions

struct QuickActionsWidgetView: View {
  let entry: RicherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let palette = RicherPalette.resolve(themeMode: entry.themeMode, systemScheme: colorScheme)

    if family == .systemSmall {
      // Small widgets only get ONE tap target on iOS (Link is ignored), so the
      // small size is a single, tidy Quick Expense tile.
      VStack(spacing: 8) {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 40, weight: .semibold))
          .foregroundColor(palette.error)
        Text(entry.lblExpense)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(palette.primaryText)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(palette.error.opacity(0.16))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(palette.error.opacity(0.38), lineWidth: 1)
          )
      )
      .widgetURL(widgetDeepLink("expense"))
      .richerWidgetContainer(palette.background)
    } else {
      fullBody(palette)
    }
  }

  private func fullBody(_ palette: RicherPalette) -> some View {
    HStack(spacing: 8) {
      actionTile(
        label: entry.lblExpense,
        systemImage: "minus.circle.fill",
        tint: palette.error,
        textColor: palette.primaryText,
        destination: widgetDeepLink("expense")
      )
      actionTile(
        label: entry.lblIncome,
        systemImage: "plus.circle.fill",
        tint: palette.success,
        textColor: palette.primaryText,
        destination: widgetDeepLink("income")
      )
      actionTile(
        label: entry.lblTransfer,
        systemImage: "arrow.left.arrow.right.circle.fill",
        tint: palette.gold,
        textColor: palette.primaryText,
        destination: widgetDeepLink("transfer")
      )
    }
    .richerWidgetContainer(palette.background)
  }

  private func actionTile(
    label: String,
    systemImage: String,
    tint: Color,
    textColor: Color,
    destination: URL
  ) -> some View {
    Link(destination: destination) {
      VStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: 22, weight: .semibold))
          .foregroundColor(tint)
        Text(label)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(textColor)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical, 8)
      .padding(.horizontal, 4)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(tint.opacity(0.16))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(tint.opacity(0.38), lineWidth: 1)
          )
      )
    }
  }
}

struct RicherQuickActionsWidget: Widget {
  let kind: String = "RicherQuickActionsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RicherTimelineProvider()) { entry in
      QuickActionsWidgetView(entry: entry)
    }
    .configurationDisplayName("Richer • Quick Actions")
    .description("Log Expense, Income, or Transfer in one tap.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Widget 2: Budget Pulse

struct BudgetPulseWidgetView: View {
  let entry: RicherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let palette = RicherPalette.resolve(themeMode: entry.themeMode, systemScheme: colorScheme)
    let isOver = entry.hasBudget && entry.budgetStatus == "over"
    let barColor: Color = {
      if !entry.hasBudget { return palette.success }
      switch entry.budgetStatus {
      case "over": return palette.error
      case "warning": return palette.warning
      default: return palette.success
      }
    }()

    let isStale = entry.hasBudget && entry.isBudgetStale

    let headerLabel: String = {
      if !entry.hasBudget || isStale { return "Richer" }
      return isOver ? entry.lblOverBudget : entry.lblSafePerDay
    }()

    let heroValue: String = {
      if !entry.hasBudget { return entry.lblNoBudget }
      if isStale { return entry.lblStale }
      return isOver ? entry.display(entry.budgetRemainingFmt) : entry.display(entry.safePerDayFmt)
    }()

    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text(headerLabel)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(palette.secondaryText)
          .lineLimit(1)
        Spacer(minLength: 2)
        privacyToggleControl(isMasked: entry.isMasked, color: palette.secondaryText)
        if family != .systemSmall {
          // No budget yet: "+" creates one instead of logging an expense.
          quickExpenseBadge(
            destination: widgetDeepLink(entry.hasBudget ? "expense" : "budget-new")
          )
        }
      }

      Spacer(minLength: 0)

      Text(heroValue)
        .font(.system(size: isStale ? 14 : (family == .systemSmall ? 17 : 20), weight: .bold))
        .foregroundColor(isOver && !isStale ? palette.error : palette.primaryText)
        .lineLimit(isStale ? 2 : 1)
        .minimumScaleFactor(0.7)
        .privacySensitive(entry.hasBudget && !isStale)

      if entry.hasBudget && !isStale {
        Text("\(entry.lblBudgetLeft): \(entry.display(entry.budgetRemainingFmt))")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(palette.secondaryText)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .privacySensitive()
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(palette.secondaryText.opacity(0.22))
            .frame(height: 6)
          Capsule()
            .fill(barColor)
            .frame(
              width: (isStale ? 0 : max(0, min(1.0, CGFloat(entry.budgetProgressPct) / 100.0)))
                * geo.size.width,
              height: 6
            )
        }
      }
      .frame(height: 6)

      Text(entry.hasBudget && !isStale ? entry.lblDaysLeft : "Richer")
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(palette.gold)
        .lineLimit(1)
    }
    .widgetURL(widgetDeepLink(entry.hasBudget ? "budget" : "budget-new"))
    .richerWidgetContainer(palette.background)
  }
}

struct RicherBudgetPulseWidget: Widget {
  let kind: String = "RicherBudgetPulseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RicherTimelineProvider()) { entry in
      BudgetPulseWidgetView(entry: entry)
    }
    .configurationDisplayName("Richer • Budget Pulse")
    .description("Daily safe-to-spend allowance and monthly budget progress.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Widget 3: Cash Flow Snapshot

struct CashFlowWidgetView: View {
  let entry: RicherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = RicherPalette.resolve(themeMode: entry.themeMode, systemScheme: colorScheme)

    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 6) {
        VStack(alignment: .leading, spacing: 2) {
          Text("\(entry.profileName) • \(entry.lblTodaySpend)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(palette.gold)
            .lineLimit(1)
          Text(entry.display(entry.todayExpenseFmt))
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(palette.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .privacySensitive()
        }
        Spacer(minLength: 4)
        privacyToggleControl(isMasked: entry.isMasked, color: palette.secondaryText)
        quickExpenseBadge()
      }

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        flowPill(
          label: entry.lblMonthIn,
          value: entry.display(entry.monthIncomeFmt),
          tint: palette.success,
          secondaryText: palette.secondaryText
        )
        flowPill(
          label: entry.lblMonthOut,
          value: entry.display(entry.monthExpenseFmt),
          tint: palette.error,
          secondaryText: palette.secondaryText
        )
      }
    }
    .widgetURL(widgetDeepLink("overview"))
    .richerWidgetContainer(palette.background)
  }

  private func flowPill(
    label: String,
    value: String,
    tint: Color,
    secondaryText: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(secondaryText)
        .lineLimit(1)
      Text(value)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .privacySensitive()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(tint.opacity(0.15))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    )
  }
}

struct RicherCashFlowWidget: Widget {
  let kind: String = "RicherCashFlowWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RicherTimelineProvider()) { entry in
      CashFlowWidgetView(entry: entry)
    }
    .configurationDisplayName("Richer • Cash Flow")
    .description("Today's spending and monthly cash flow with privacy toggle.")
    .supportedFamilies([.systemMedium])
  }
}

// MARK: - Bundle Entry Point

@main
struct RicherWidgetBundle: WidgetBundle {
  var body: some Widget {
    RicherQuickActionsWidget()
    RicherBudgetPulseWidget()
    RicherCashFlowWidget()
  }
}
