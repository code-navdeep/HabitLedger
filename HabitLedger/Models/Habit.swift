import Foundation

struct Habit: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: HabitType
    var target: Double?
    var goal: HabitGoal
    var schedule: Schedule
    var isArchived: Bool
    var entries: [HabitEntry]
    var createdDate: Date

    enum HabitType: String, CaseIterable, Codable {
        case binary = "binary"
        case numerical = "numerical"

        var displayName: String {
            switch self {
            case .binary:
                return "Yes/No"
            case .numerical:
                return "Numerical"
            }
        }
    }

    enum HabitGoal: String, CaseIterable, Codable {
        case adopt = "adopt"
        case quit = "quit"

        var displayName: String {
            switch self {
            case .adopt:
                return "Adopt"
            case .quit:
                return "Quit"
            }
        }
    }

    init(name: String, type: HabitType, target: Double? = nil, goal: HabitGoal = .adopt, schedule: Schedule = .daily, createdDate: Date = Date()) {
        self.name = name
        self.type = type
        self.target = target
        self.goal = goal
        self.schedule = schedule
        self.isArchived = false
        self.entries = []
        self.createdDate = Calendar.current.startOfDay(for: createdDate)
    }

    func isScheduled(on date: Date) -> Bool {
        schedule.isScheduled(on: date)
    }

    // MARK: - Entry Access

    func getEntry(for date: Date) -> HabitEntry? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
    }

    mutating func setEntry(_ value: HabitEntry.HabitValue, for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Remove existing entry for this date
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }

        // Add new entry
        let entry = HabitEntry(date: normalizedDate, value: value)
        entries.append(entry)
    }

    mutating func removeEntry(for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
    }

    // MARK: - Convenience Accessors

    func isCompleted(for date: Date) -> Bool {
        guard type == .binary else { return false }
        return getEntry(for: date)?.value.boolValue ?? false
    }

    func getNumericalValue(for date: Date) -> Double {
        guard type == .numerical else { return 0 }
        return getEntry(for: date)?.value.numericalValue ?? 0
    }
}