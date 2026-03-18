import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isWindowVisible: Bool = false
    @Published var isMirrored: Bool = true
    @Published var windowOpacity: Double = 0.85

    let cameraManager = CameraManager()
    let teleprompterState = TeleprompterState()
    let loginItemManager = LoginItemManager()
    let recordingManager = RecordingManager()

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
