import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isWindowVisible: Bool = false
    @Published var hasCompletedOnboarding: Bool

    @Published var isMirrored: Bool {
        didSet { UserDefaults.standard.set(isMirrored, forKey: "isMirrored") }
    }
    @Published var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity") }
    }

    let cameraManager = CameraManager()
    let teleprompterState = TeleprompterState()
    let loginItemManager = LoginItemManager()
    let recordingManager = RecordingManager()

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isMirrored = UserDefaults.standard.object(forKey: "isMirrored") as? Bool ?? true
        self.windowOpacity = UserDefaults.standard.object(forKey: "windowOpacity") as? Double ?? 0.85
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func toggleWindow() {
        isWindowVisible.toggle()
        if isWindowVisible {
            if !cameraManager.isConfigured {
                cameraManager.configureSession()
            }
            cameraManager.startSession()
        } else {
            if recordingManager.isRecording {
                recordingManager.stopRecording(movieOutput: cameraManager.movieOutput)
            }
            teleprompterState.stopScrolling()
            cameraManager.stopSession()
        }
    }

    func toggleRecording() {
        recordingManager.toggleRecording(movieOutput: cameraManager.movieOutput)
    }
}
