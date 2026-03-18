import ServiceManagement
import SwiftUI

@MainActor
class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            print("Login item registration failed: \(error)")
        }
    }
}
