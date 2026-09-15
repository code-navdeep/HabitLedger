import SwiftUI
import Charts

struct HabitProgressView: View {
    @EnvironmentObject var habitStore: HabitStore
    let habit: Habit
    let onDismiss: () -> Void

    @State private var contentHeight: CGFloat = 0
    private let maxContentHeight: CGFloat = 520

    // For weekly navigator
    @State private var weekOfYear: Int
    @State private var yearForWeek: Int

    // For monthly navigator
    @State private var month: Int
    @State private var year: Int

    // Day being retro-logged from the numerical chart
    @State private var editingDay: EditingDay?

    struct EditingDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    // We need a custom init to set the initial state
    init(habit: Habit, onDismiss: @escaping () -> Void) {
        self.habit = habit
        self.onDismiss = onDismiss
        let today = Date()
        let calendar = Calendar.current
        // For weekly navigator
        self._weekOfYear = State(initialValue: calendar.component(.weekOfYear, from: today))
        self._yearForWeek = State(initialValue: calendar.component(.yearForWeekOfYear, from: today))
        // For monthly navigator
        self._month = State(initialValue: calendar.component(.month, from: today))
        self._year = State(initialValue: calendar.component(.year, from: today))
    }

    /// The live habit from the store. `habit` is a value copy taken when the view
    /// was opened; click-to-log mutates the store, so reads must go through this.
    private var currentHabit: Habit {
        habitStore.habits.first(where: { $0.id == habit.id }) ?? habit
    }

    // --- Logic for Monthly Streak View ---
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month))!
        return formatter.string(from: date)
    }

    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.compactMap { day -> Date? in
            var components = dateComponents
            components.day = day
            return calendar.date(from: components)
        }
    }

    private var firstDayOfMonthWeekday: Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        // weekday: 1 = Sunday, 2 = Monday, ...
        return calendar.component(.weekday, from: date)
    }

    /// Leading empty cells, respecting the user's first weekday (Mon-first locales included).
    private var leadingEmptyCells: Int {
        (firstDayOfMonthWeekday - Calendar.current.firstWeekday + 7) % 7
    }

    /// Weekday symbols ordered by the user's calendar (e.g. M T W T F S S for Mon-first).
    private var orderedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    // The start of the currently selected week
    private var barChartStartDate: Date {
        let calendar = Calendar.current
        let components = DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeek)
        return calendar.date(from: components)!
    }

    // The 7 days of the selected week
    private var barChartDateRange: [Date] {
        (0..<7).map { i in
            Calendar.current.date(byAdding: .day, value: i, to: barChartStartDate)!
        }
    }

    // The formatted label for the selected week
    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startDate = barChartStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate)!
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    private var yAxisMax: Double {
        let maxDataValue = barChartDateRange.map { currentHabit.getNumericalValue(for: $0) }.max() ?? 0
        let targetValue = currentHabit.target ?? 0
        let topValue = max(maxDataValue, targetValue)
        return topValue == 0 ? 10 : topValue * 1.2 // Return a default max if all values are 0
    }

    // Checks if the currently displayed week is the current calendar week
    private var isDisplayingCurrentWeek: Bool {
        let today = Date()
        let calendar = Calendar.current
        return self.weekOfYear == calendar.component(.weekOfYear, from: today) &&
               self.yearForWeek == calendar.component(.yearForWeekOfYear, from: today)
    }

    // Checks if the currently displayed month is the current calendar month
    private var isDisplayingCurrentMonth: Bool {
        let today = Date()
        let calendar = Calendar.current
        return self.month == calendar.component(.month, from: today) &&
               self.year == calendar.component(.year, from: today)
    }

    /// The habit's start month/week bound the back navigation.
    private var isDisplayingEarliestMonth: Bool {
        let calendar = Calendar.current
        guard let displayedMonthStart = calendar.date(from: DateComponents(year: year, month: month)) else { return true }
        let created = calendar.dateComponents([.year, .month], from: currentHabit.createdDate)
        guard let createdMonthStart = calendar.date(from: DateComponents(year: created.year, month: created.month)) else { return true }
        return displayedMonthStart <= createdMonthStart
    }

    private var isDisplayingEarliestWeek: Bool {
        let calendar = Calendar.current
        guard let createdWeekStart = calendar.dateInterval(of: .weekOfYear, for: currentHabit.createdDate)?.start else { return true }
        return barChartStartDate <= createdWeekStart
    }

    // Function to handle changing the week
    private func changeWeek(by amount: Int) {
        let calendar = Calendar.current
        let startDateOfWeek = self.barChartStartDate
        guard let newDate = calendar.date(byAdding: .weekOfYear, value: amount, to: startDateOfWeek) else { return }

        self.weekOfYear = calendar.component(.weekOfYear, from: newDate)
        self.yearForWeek = calendar.component(.yearForWeekOfYear, from: newDate)
    }

    // Function to handle changing the month
    private func changeMonth(by amount: Int) {
        let calendar = Calendar.current
        let currentDateComponents = DateComponents(year: self.year, month: self.month)
        guard let currentDate = calendar.date(from: currentDateComponents),
              let newDate = calendar.date(byAdding: .month, value: amount, to: currentDate) else { return }

        self.month = calendar.component(.month, from: newDate)
        self.year = calendar.component(.year, from: newDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (fixed, not scrollable)
            HStack {
                Text(currentHabit.name)
                    .textStyle(.title2)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if currentHabit.type == .binary {
                        binaryContent
                    } else {
                        numericalContent
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .frame(height: min(contentHeight, maxContentHeight))
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }

    // MARK: - Binary (calendar + heatmap)

    @ViewBuilder
    private var binaryContent: some View {
        let streaks = habitStore.calculateStreaks(for: currentHabit)
        let suffix = currentHabit.schedule.isWeeklyQuota ? "w" : ""

        // Stats
        HStack(spacing: Theme.spacing(4)) {
            VStack {
                Text("\(streaks.current)\(suffix)")
                    .textStyle(.title1)
                Text("Current Streak")
                    .textStyle(.caption)
            }
            VStack {
                Text("\(streaks.longest)\(suffix)")
                    .textStyle(.title1)
                Text("Longest Streak")
                    .textStyle(.caption)
            }
        }
        .foregroundColor(.theme.textPrimary)
        .padding()

        // Month Navigator
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(isDisplayingEarliestMonth)

            Spacer()
            Text(monthLabel)
                .font(.headline)
            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(isDisplayingCurrentMonth)
        }
        .padding(.horizontal)

        // Grid
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: Theme.spacing(1)) {
            // Weekday header, ordered by the user's calendar
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundColor(.theme.textTertiary)
            }

            // Empty cells before the first day of the month
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                VStack {}
            }

            ForEach(daysInMonth, id: \.self) { date in
                calendarCell(for: date)
            }
        }
        .padding()

        // Year heatmap
        YearHeatmapView(habit: currentHabit)
            .padding(.horizontal)
            .padding(.bottom)
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: currentHabit.createdDate)
        let canLog = day <= today && day >= createdDay
        let result = habitStore.dayResult(for: currentHabit, on: date)

        VStack {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption2)
                .foregroundColor(.theme.textSecondary)
            dayCircle(for: result)
                .frame(width: 20, height: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canLog else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                habitStore.cycleBinaryEntry(for: currentHabit.id, on: date)
            }
        }
    }

    @ViewBuilder
    private func dayCircle(for result: DayResult) -> some View {
        switch result {
        case .success:
            Circle().fill(Color.green)
        case .failure:
            Circle().fill(Color.red.opacity(0.55))
        case .silentSuccess:
            Circle().strokeBorder(Color.theme.textTertiary, lineWidth: 1.5)
        case .skipped:
            Circle().fill(Color.primary.opacity(0.05))
        }
    }

    // MARK: - Numerical (stats + weekly chart)

    @ViewBuilder
    private var numericalContent: some View {
        let stats = habitStore.calculateNumericalStats(for: currentHabit)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: currentHabit.createdDate)

        // Stats
        HStack(spacing: Theme.spacing(4)) {
            if currentHabit.target != nil {
                VStack {
                    Text(String(format: "%.0f%%", stats.successRate))
                        .textStyle(.title1)
                    Text("Success Rate")
                        .textStyle(.caption)
                }
            }
            VStack {
                Text(String(format: "%.1f", stats.average))
                    .textStyle(.title1)
                Text("30-Day Avg")
                    .textStyle(.caption)
            }
        }
        .foregroundColor(.theme.textPrimary)
        .padding()

        // Week Navigator
        HStack {
            Button(action: { changeWeek(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(isDisplayingEarliestWeek)

            Spacer()
            Text(dateRangeLabel)
                .font(.headline)
            Spacer()

            Button(action: { changeWeek(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(isDisplayingCurrentWeek)
        }
        .padding(.horizontal)
        .padding(.top)

        // Chart — tap a day to log it retroactively
        Chart(barChartDateRange, id: \.self) { date in
            // Future days get no bar at all
            if calendar.startOfDay(for: date) <= today {
                let value = currentHabit.getNumericalValue(for: date)
                let result = habitStore.dayResult(for: currentHabit, on: date)

                BarMark(
                    x: .value("Date", date, unit: .day),
                    y: .value("Value", value)
                )
                .foregroundStyle(barColor(for: result))
            }

            if let target = currentHabit.target {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Color.theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
        }
        .chartYScale(domain: 0...yAxisMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geo[plotFrame].origin
                        guard let date: Date = proxy.value(atX: location.x - origin.x) else { return }
                        let day = calendar.startOfDay(for: date)
                        guard day <= today, day >= createdDay else { return }
                        editingDay = EditingDay(date: day)
                    }
            }
        }
        .popover(item: $editingDay) { editing in
            VStack(spacing: Theme.spacing(1.5)) {
                Text(editing.date, format: .dateTime.weekday(.wide).month().day())
                    .textStyle(.headline)
                    .foregroundColor(.theme.textPrimary)
                CustomStepper(value: Binding(
                    get: { currentHabit.getNumericalValue(for: editing.date) },
                    set: { habitStore.updateNumericalValue(for: currentHabit.id, on: editing.date, to: $0) }
                ), target: currentHabit.target)
            }
            .padding()
        }
        .padding()
    }

    private func barColor(for result: DayResult) -> Color {
        switch result {
        case .success, .silentSuccess:
            return .green
        case .failure:
            return .red
        case .skipped:
            return Color.theme.textTertiary
        }
    }
}
