import Foundation
import Combine
import SwiftUI

enum SaveState: Equatable {
    case saved
    case saving
    case error(String)
}

class HabitStore: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var currentDate = Date()
    @Published var accentColor: Color = .accentColor
    @Published var saveState: SaveState = .saved
    @Published var error: RepositoryError?

    private let repository: HabitRepository
    private let service: HabitService
    private var cancellables = Set<AnyCancellable>()
    /// Serial queue so two saves can never interleave their backup/write steps.
    private let saveQueue = DispatchQueue(label: "studio.liberated.HabitLedger.save", qos: .utility)
    private var dayChangeObserver: NSObjectProtocol?

    /// Cache for streak calculations (habitID -> StreakData)
    private var streakCache: [UUID: StreakData] = [:]
    /// Cache for numerical stats (habitID -> NumericalStats)
    private var statsCache: [UUID: NumericalStats] = [:]
    /// Date when cache was last valid
    private var cacheDate: Date?

    init(repository: HabitRepository = HabitRepository(), service: HabitService = HabitService()) {
        self.repository = repository
        self.service = service

        loadData()
        loadAccentColor()

        // dropFirst: the just-loaded value must not trigger a save at launch.
        $habits
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.goToToday()
        }
    }

    deinit {
        if let dayChangeObserver {
            NotificationCenter.default.removeObserver(dayChangeObserver)
        }
    }

    // MARK: - Data Persistence

    private func saveData() {
        saveState = .saving

        // Capture habits on main actor before dispatching to background
        let habitsToSave = habits

        saveQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.repository.save(habitsToSave)
                DispatchQueue.main.async {
                    self.saveState = .saved
                }
            } catch {
                DispatchQueue.main.async {
                    if let repoError = error as? RepositoryError {
                        self.error = repoError
                        self.saveState = .error(repoError.localizedDescription)
                    } else {
                        self.saveState = .error("Failed to save")
                    }
                }
            }
        }
    }

    private func loadData() {
        do {
            habits = try repository.load()
        } catch {
            if let repoError = error as? RepositoryError {
                self.error = repoError
            }
            // Load defaults on error
            habits = repository.loadDefaults()
        }
    }

    // MARK: - Accent Color

    private func loadAccentColor() {
        if let colorName = UserDefaults.standard.string(forKey: "accentColor"),
           let color = AccentColor.allColors.first(where: { $0.name == colorName }) {
            accentColor = color.color
        }
    }

    func setAccentColor(_ color: Color) {
        accentColor = color
        if let colorName = AccentColor.allColors.first(where: { $0.color == color })?.name {
            UserDefaults.standard.set(colorName, forKey: "accentColor")
        }
    }

    // MARK: - Habit Updates

    func updateCompletion(for habitID: Habit.ID, on date: Date, to isComplete: Bool) {
        if let index = habits.firstIndex(where: { $0.id == habitID }) {
            habits[index].setEntry(.binary(isComplete), for: date)
            invalidateCache(for: habitID)
        }
    }

    func updateNumericalValue(for habitID: Habit.ID, on date: Date, to value: Double) {
        if let index = habits.firstIndex(where: { $0.id == habitID }) {
            habits[index].setEntry(.numerical(value), for: date)
            invalidateCache(for: habitID)
        }
    }

    /// Removes the entry for the date, returning the day to "unlogged".
    func clearEntry(for habitID: Habit.ID, on date: Date) {
        if let index = habits.firstIndex(where: { $0.id == habitID }) {
            habits[index].removeEntry(for: date)
            invalidateCache(for: habitID)
        }
    }

    /// Calendar click-to-log for binary habits: unlogged → Yes → No → unlogged.
    func cycleBinaryEntry(for habitID: Habit.ID, on date: Date) {
        guard let index = habits.firstIndex(where: { $0.id == habitID }),
              habits[index].type == .binary else { return }
        switch habits[index].getEntry(for: date)?.value.boolValue {
        case nil:
            habits[index].setEntry(.binary(true), for: date)
        case true?:
            habits[index].setEntry(.binary(false), for: date)
        case false?:
            habits[index].removeEntry(for: date)
        }
        invalidateCache(for: habitID)
    }

    // MARK: - Date Navigation

    func previousDay() {
        currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
    }

    func nextDay() {
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    func goToToday() {
        currentDate = Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(currentDate)
    }

    /// Earliest start date among unarchived habits; lower bound for day navigation.
    var earliestStartDate: Date? {
        habits.filter { !$0.isArchived }.map(\.createdDate).min()
    }

    // MARK: - CRUD Operations

    func addHabit(_ habit: Habit) {
        habits.append(habit)
    }

    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            invalidateCache(for: habit.id)
        }
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        invalidateCache(for: habit.id)
    }

    func setArchived(_ archived: Bool, for habitID: Habit.ID) {
        if let index = habits.firstIndex(where: { $0.id == habitID }) {
            habits[index].isArchived = archived
        }
    }

    func moveHabit(fromIndex: Int, toIndex: Int) {
        guard habits.indices.contains(fromIndex), habits.indices.contains(toIndex), fromIndex != toIndex else { return }
        let habit = habits.remove(at: fromIndex)
        habits.insert(habit, at: toIndex)
    }

    // MARK: - Habit Queries

    /// Habits that should appear on the given day: unarchived and already started.
    func activeHabits(on date: Date) -> [Habit] {
        let day = Calendar.current.startOfDay(for: date)
        return habits.filter { !$0.isArchived && Calendar.current.startOfDay(for: $0.createdDate) <= day }
    }

    var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }

    // MARK: - Cache Management

    private func invalidateCacheIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if cacheDate == nil || !Calendar.current.isDate(cacheDate!, inSameDayAs: today) {
            streakCache.removeAll()
            statsCache.removeAll()
            cacheDate = today
        }
    }

    private func invalidateCache(for habitID: UUID) {
        streakCache.removeValue(forKey: habitID)
        statsCache.removeValue(forKey: habitID)
    }

    // MARK: - Business Logic (Delegated to Service with Caching)

    func calculateStreaks(for habit: Habit) -> StreakData {
        invalidateCacheIfNeeded()

        if let cached = streakCache[habit.id] {
            return cached
        }

        let streaks = service.calculateStreaks(for: habit)
        streakCache[habit.id] = streaks
        return streaks
    }

    func calculateNumericalStats(for habit: Habit) -> NumericalStats {
        invalidateCacheIfNeeded()

        if let cached = statsCache[habit.id] {
            return cached
        }

        let stats = service.calculateNumericalStats(for: habit)
        statsCache[habit.id] = stats
        return stats
    }

    func isSuccessful(for habit: Habit, on date: Date) -> Bool {
        service.isSuccessful(habit: habit, on: date)
    }

    func dayResult(for habit: Habit, on date: Date) -> DayResult {
        service.dayResult(for: habit, on: date)
    }

    // MARK: - Export / Import

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(habits)
    }

    func exportCSV() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var rows = ["habit,type,goal,date,value"]
        for habit in habits {
            let name = "\"" + habit.name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            for entry in habit.entries.sorted(by: { $0.date < $1.date }) {
                let value: String
                switch entry.value {
                case .binary(let didIt):
                    value = didIt ? "yes" : "no"
                case .numerical(let number):
                    value = String(number)
                }
                rows.append("\(name),\(habit.type.rawValue),\(habit.goal.rawValue),\(formatter.string(from: entry.date)),\(value)")
            }
        }
        return rows.joined(separator: "\n")
    }

    /// Replaces all habits with the decoded, sanitized contents of the given JSON data.
    func importHabits(from data: Data) throws {
        let decoded = try JSONDecoder().decode([Habit].self, from: data)
        habits = repository.validateAndSanitize(decoded)
        streakCache.removeAll()
        statsCache.removeAll()
    }
}
