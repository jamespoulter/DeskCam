import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isWindowVisible: Bool = false
    @Published var isMirrored: Bool = true
    @Published var windowOpacity: Double = 0.85
    @Published var windowSize: CGSize = CGSize(width: 320, height: 240)

    let cameraManager = CameraManager()
    let teleprompterState = TeleprompterState()
    let loginItemManager = LoginItemManager()
    let recordingManager = RecordingManager()

    private var hasConfiguredSession = false

    func toggleWindow() {
        isWindowVisible.toggle()
        if isWindowVisible {
            if !hasConfiguredSession {
                cameraManager.configureSession(recordingManager: recordingManager)
                hasConfiguredSession = true
            }
            cameraManager.startSession()
        } else {
            if recordingManager.isRecording {
                recordingManager.stopRecording()
            }
            cameraManager.stopSession()
        }
    }
}
