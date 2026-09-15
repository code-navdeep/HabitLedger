import Foundation

/// How often a habit is expected to be performed.
/// - `daily`: every day counts.
/// - `weekdays`: only the given Calendar weekday numbers (1 = Sunday … 7 = Saturday) count;
///   other days are skipped by streak and stat calculations (they neither break nor extend streaks).
/// - `timesPerWeek`: any N explicitly-logged successful days within a calendar week satisfy the week;
///   streaks for these habits are counted in weeks, not days.
enum Schedule: Codable, Hashable {
    case daily
    case weekdays(Set<Int>)
    case timesPerWeek(Int)

    func isScheduled(on date: Date) -> Bool {
        switch self {
        case .daily, .timesPerWeek:
            return true
        case .weekdays(let days):
            return days.contains(Calendar.current.component(.weekday, from: date))
        }
    }

    var isWeeklyQuota: Bool {
        if case .timesPerWeek = self { return true }
        return false
    }
}
