import Foundation

enum RepositoryError: LocalizedError, Equatable {
    case saveFailed(underlying: String)
    case loadFailed(underlying: String)
    case directoryCreationFailed
    case corruptedData

    /// Create a saveFailed error from any Error
    static func saveFailed(from error: Error) -> RepositoryError {
        .saveFailed(underlying: error.localizedDescription)
    }

    /// Create a loadFailed error from any Error
    static func loadFailed(from error: Error) -> RepositoryError {
        .loadFailed(underlying: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save your habits. Please try again."
        case .loadFailed:
            return "Failed to load your habits. Your data may be corrupted."
        case .directoryCreationFailed:
            return "Failed to create storage directory."
        case .corruptedData:
            return "Your habit data appears to be corrupted. Loading defaults."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return "Check that you have enough disk space and permissions."
        case .loadFailed, .corruptedData:
            return "Your previous data will be backed up and fresh defaults loaded."
        case .directoryCreationFailed:
            return "Check your app permissions in System Settings."
        }
    }
}

class HabitRepository {
    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HabitLedger", isDirectory: true)
    }

    private var dataFileURL: URL {
        documentsDirectory.appendingPathComponent("habit_data.json")
    }

    private var backupFileURL: URL {
        documentsDirectory.appendingPathComponent("habit_data_backup.json")
    }

    init() {
        createDirectoryIfNeeded()
    }

    func save(_ habits: [Habit]) throws {
        do {
            // Create backup before saving (remove old backup first)
            if fileManager.fileExists(atPath: dataFileURL.path) {
                try? fileManager.removeItem(at: backupFileURL)
                try? fileManager.copyItem(at: dataFileURL, to: backupFileURL)
            }

            let data = try JSONEncoder().encode(habits)
            try data.write(to: dataFileURL, options: .atomic)
        } catch {
            throw RepositoryError.saveFailed(from: error)
        }
    }

    func loadDefaults() -> [Habit] {
        return loadDefaultHabits()
    }

    func load() throws -> [Habit] {
        guard fileManager.fileExists(atPath: dataFileURL.path) else {
            return loadDefaultHabits()
        }

        do {
            let data = try Data(contentsOf: dataFileURL)
            var habits = try JSONDecoder().decode([Habit].self, from: data)
            habits = validateAndSanitize(habits)
            return habits
        } catch {
            // Try to restore from backup
            if fileManager.fileExists(atPath: backupFileURL.path),
               let backupData = try? Data(contentsOf: backupFileURL),
               var habits = try? JSONDecoder().decode([Habit].self, from: backupData) {
                habits = validateAndSanitize(habits)
                return habits
            }

            throw RepositoryError.loadFailed(from: error)
        }
    }

    // MARK: - Data Validation

    /// Validates and sanitizes loaded habits, removing invalid data
    func validateAndSanitize(_ habits: [Habit]) -> [Habit] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return habits.map { habit in
            var sanitizedHabit = habit

            // Filter out future-dated entries and validate entry types
            sanitizedHabit.entries = habit.entries.compactMap { entry in
                // Remove future-dated entries
                let entryDate = Calendar.current.startOfDay(for: entry.date)
                guard entryDate < tomorrow else {
                    return nil
                }

                // Validate entry type matches habit type
                switch (habit.type, entry.value) {
                case (.binary, .binary):
                    return entry
                case (.numerical, .numerical(let value)):
                    // Clamp negative values to 0
                    if value < 0 {
                        return HabitEntry(date: entry.date, value: .numerical(0))
                    }
                    return entry
                default:
                    // Entry type doesn't match habit type - skip it
                    return nil
                }
            }

            return sanitizedHabit
        }
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadDefaultHabits() -> [Habit] {
        return [
            Habit(name: "Meditation", type: .binary),
            Habit(name: "Exercise", type: .binary),
            Habit(name: "Alcohol", type: .numerical, target: 2, goal: .quit),
            Habit(name: "Reading", type: .numerical, target: 30)
        ]
    }
}
