import Foundation

struct StreakData {
    let current: Int
    let longest: Int
}

struct NumericalStats {
    let successRate: Double
    let average: Double
}

/// Outcome of a single day for a habit.
enum DayResult {
    /// An entry was logged and it satisfies the goal.
    case success
    /// Binary habits only: no entry was logged. Counts as a success
    /// (streaks break only on confessed failures) but is rendered neutrally.
    case silentSuccess
    case failure
    /// The day doesn't participate: it is in the future, before the habit's
    /// start date, or not scheduled. Skipped days neither break nor extend streaks.
    case skipped
    /// Today only, not judged until midnight: nothing logged, or a number still short
    /// of an adopt goal. Neither counts nor breaks; at midnight it becomes the usual
    /// verdict (Yes/No → silent success, number → failure).
    case pending

    var countsAsSuccess: Bool { self == .success || self == .silentSuccess }
}

class HabitService {

    // MARK: - Day Evaluation (single source of truth)

    /// Success rules:
    /// - Binary: unlogged = silent success. Adopt: Yes = success, No = failure.
    ///   Quit: No = success, Yes = failure.
    /// - Numerical: unlogged = failure (value counts as 0). With a target:
    ///   adopt needs value >= target, quit needs value <= target. Without one:
    ///   adopt needs value > 0, quit needs value == 0.
    /// - Today: an unlogged day, or a number short of an adopt goal, is `.pending`
    ///   until midnight; the rules above apply once the day is over.
    func dayResult(for habit: Habit, on date: Date) -> DayResult {
        evaluate(habit: habit, on: Calendar.current.startOfDay(for: date), entry: habit.getEntry(for: date))
    }

    func isSuccessful(habit: Habit, on date: Date) -> Bool {
        dayResult(for: habit, on: date).countsAsSuccess
    }

    private func evaluate(habit: Habit, on day: Date, entry: HabitEntry?) -> DayResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard day <= today,
              day >= calendar.startOfDay(for: habit.createdDate),
              habit.isScheduled(on: day) else { return .skipped }

        // Every caller passes a start-of-day date.
        let isToday = day == today

        switch habit.type {
        case .binary:
            guard let didIt = entry?.value.boolValue else { return isToday ? .pending : .silentSuccess }
            let success = habit.goal == .adopt ? didIt : !didIt
            return success ? .success : .failure
        case .numerical:
            guard let value = entry?.value.numericalValue else { return isToday ? .pending : .failure }
            let success: Bool
            if let target = habit.target {
                success = habit.goal == .adopt ? value >= target : value <= target
            } else {
                success = habit.goal == .adopt ? value > 0 : value == 0
            }
            // A value short of an adopt goal counts as not logged until the day ends.
            if !success && isToday && habit.goal == .adopt { return .pending }
            return success ? .success : .failure
        }
    }

    // MARK: - Streaks

    func calculateStreaks(for habit: Habit) -> StreakData {
        if habit.schedule.isWeeklyQuota {
            return calculateWeeklyStreaks(for: habit)
        }
        return calculateDailyStreaks(for: habit)
    }

    private func calculateDailyStreaks(for habit: Habit) -> StreakData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: habit.createdDate)
        let entries = entryMap(for: habit)

        // A numerical habit whose logged value already fails today (a quit habit over
        // its limit) starts counting from yesterday, so today doesn't break the streak
        // until it's over. Unlogged or short days are `.pending` and skipped below.
        var startOffset = 0
        if habit.type == .numerical,
           evaluate(habit: habit, on: today, entry: entries[today]) == .failure {
            startOffset = 1
        }

        var current = 0
        currentLoop: for i in startOffset..<365 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
            let day = calendar.startOfDay(for: date)
            if day < createdDay { break }
            switch evaluate(habit: habit, on: day, entry: entries[day]) {
            case .success, .silentSuccess: current += 1
            case .skipped, .pending: continue
            case .failure: break currentLoop
            }
        }

        var longest = 0
        var running = 0
        for i in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let day = calendar.startOfDay(for: date)
            if day < createdDay { break }
            switch evaluate(habit: habit, on: day, entry: entries[day]) {
            case .success, .silentSuccess: running += 1
            case .skipped, .pending: continue
            case .failure:
                longest = max(longest, running)
                running = 0
            }
        }
        longest = max(longest, running)

        return StreakData(current: current, longest: longest)
    }

    /// Streaks for `timesPerWeek` habits are counted in whole weeks. A week is met
    /// when it contains at least N explicitly-logged successful days (silent
    /// successes don't count toward the quota). The current week counts toward the
    /// streak once met; while it is unmet but still achievable it neither counts
    /// nor breaks the streak.
    private func calculateWeeklyStreaks(for habit: Habit) -> StreakData {
        guard case .timesPerWeek(let quota) = habit.schedule, quota > 0,
              let currentWeekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return StreakData(current: 0, longest: 0)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: habit.createdDate)
        let entries = entryMap(for: habit)

        func loggedSuccesses(inWeekStarting weekStart: Date) -> Int {
            var count = 0
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                let day = calendar.startOfDay(for: date)
                if evaluate(habit: habit, on: day, entry: entries[day]) == .success {
                    count += 1
                }
            }
            return count
        }

        func weekEnd(startingAt weekStart: Date) -> Date {
            calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        }

        // Current week: met, still achievable, or already failed.
        let successesThisWeek = loggedSuccesses(inWeekStarting: currentWeekStart)
        let todayIsLoggedSuccess = evaluate(habit: habit, on: today, entry: entries[today]) == .success
        let daysRemaining = (calendar.dateComponents([.day], from: today, to: weekEnd(startingAt: currentWeekStart)).day ?? 0)
            + (todayIsLoggedSuccess ? 0 : 1)
        let currentWeekMet = successesThisWeek >= quota
        let currentWeekAchievable = currentWeekMet || successesThisWeek + max(0, daysRemaining) >= quota

        var current = 0
        if currentWeekAchievable {
            if currentWeekMet { current = 1 }
            var w = 1
            while w < 52 {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -w, to: currentWeekStart) else { break }
                if weekEnd(startingAt: weekStart) < createdDay { break }
                if loggedSuccesses(inWeekStarting: weekStart) >= quota {
                    current += 1
                } else {
                    break
                }
                w += 1
            }
        }

        var longest = 0
        var running = 0
        for w in 0..<52 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -w, to: currentWeekStart) else { continue }
            if weekEnd(startingAt: weekStart) < createdDay { break }
            if loggedSuccesses(inWeekStarting: weekStart) >= quota {
                running += 1
            } else if w == 0 && currentWeekAchievable {
                continue // pending current week doesn't break the run
            } else {
                longest = max(longest, running)
                running = 0
            }
        }
        longest = max(longest, running)

        return StreakData(current: current, longest: longest)
    }

    // MARK: - Numerical Stats

    func calculateNumericalStats(for habit: Habit) -> NumericalStats {
        guard habit.type == .numerical else { return NumericalStats(successRate: 0, average: 0) }

        let calendar = Calendar.current
        let createdDay = calendar.startOfDay(for: habit.createdDate)
        let entries = entryMap(for: habit)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: Date())!
        let dateRange = (0..<30).compactMap { i in
            calendar.date(byAdding: .day, value: i, to: thirtyDaysAgo)
        }

        var countedDays = 0
        var successfulDays = 0
        var totalValue: Double = 0

        // Only consider scheduled days on or after the habit existed.
        for date in dateRange {
            let day = calendar.startOfDay(for: date)
            guard day >= createdDay, habit.isScheduled(on: day) else { continue }
            let result = evaluate(habit: habit, on: day, entry: entries[day])
            // An unjudged today stays out of both the rate and the average until midnight.
            if result == .pending { continue }
            countedDays += 1
            if result.countsAsSuccess {
                successfulDays += 1
            }
            totalValue += entries[day]?.value.numericalValue ?? 0
        }

        guard countedDays > 0 else { return NumericalStats(successRate: 0, average: 0) }

        let successRate = (Double(successfulDays) / Double(countedDays)) * 100
        let average = totalValue / Double(countedDays)

        return NumericalStats(successRate: successRate, average: average)
    }

    // MARK: - Helpers

    /// Entries keyed by start-of-day for O(1) lookup during streak/stat walks.
    private func entryMap(for habit: Habit) -> [Date: HabitEntry] {
        let calendar = Calendar.current
        return Dictionary(
            habit.entries.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, last in last }
        )
    }
}
