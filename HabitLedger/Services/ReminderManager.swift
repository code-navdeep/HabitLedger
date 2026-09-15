import Combine
import Foundation
import UserNotifications

/// Schedules the single daily "log your habits" notification.
final class ReminderManager: ObservableObject {
    private static let reminderID = "daily-reminder"
    private static let enabledKey = "reminderEnabled"
    private static let timeKey = "reminderTime"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var time: Date

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if let stored = UserDefaults.standard.object(forKey: Self.timeKey) as? Date {
            time = stored
        } else {
            time = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled {
            schedule()
        } else {
            cancel()
        }
    }

    func setTime(_ newTime: Date) {
        time = newTime
        UserDefaults.standard.set(newTime, forKey: Self.timeKey)
        if isEnabled {
            schedule()
        }
    }

    private func schedule() {
        let center = UNUserNotificationCenter.current()
        let reminderTime = time
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "HabitLedger"
            content.body = "Time to log your habits."

            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger)

            center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
            center.add(request)
        }
    }

    private func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }
}
