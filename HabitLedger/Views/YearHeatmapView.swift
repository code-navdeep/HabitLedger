
import SwiftUI

/// GitHub-style 52-week grid for binary habits. Columns are weeks
/// (oldest on the left, current week on the right); rows follow the
/// user's calendar week order.
struct YearHeatmapView: View {
    @EnvironmentObject var habitStore: HabitStore
    let habit: Habit

    private let weekCount = 52
    private let cellSize: CGFloat = 5
    private let cellSpacing: CGFloat = 2

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        VStack(alignment: .leading, spacing: Theme.spacing(1)) {
            Text("Past Year")
                .textStyle(.caption)
                .foregroundColor(.theme.textSecondary)

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(0..<weekCount, id: \.self) { weekIndex in
                    let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex - (weekCount - 1), to: currentWeekStart) ?? currentWeekStart
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayOffset in
                            let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                            RoundedRectangle(cornerRadius: 1)
                                .fill(color(for: day))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func color(for day: Date) -> Color {
        switch habitStore.dayResult(for: habit, on: day) {
        case .success:
            return .green
        case .failure:
            return Color.red.opacity(0.6)
        case .silentSuccess, .pending:
            return Color.primary.opacity(0.12)
        case .skipped:
            return Color.primary.opacity(0.04)
        }
    }
}
