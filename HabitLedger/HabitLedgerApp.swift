import SwiftUI

@main
struct HabitLedgerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app lives entirely in the status item + popover owned by
        // AppDelegate; LSUIElement means this stub scene never shows.
        Settings {
            EmptyView()
        }
    }
}
