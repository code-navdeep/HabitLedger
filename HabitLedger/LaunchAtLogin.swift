import Combine
import ServiceManagement
import SwiftUI

class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ newState: Bool) {
        do {
            if newState {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            self.isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            print("Failed to update launch at login status: \(error.localizedDescription)")
            // On failure, revert the state to reflect the truth from the system
            self.isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
