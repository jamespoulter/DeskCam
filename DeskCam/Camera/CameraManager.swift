import AVFoundation
import SwiftUI

@MainActor
class CameraManager: ObservableObject {
    @Published var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isRunning: Bool = false
    @Published var errorMessage: String?

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.deskcam.session")
    private var isConfigured = false

    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        permissionStatus = granted ? .authorized : .denied
        if granted && !isConfigured {
            configureSession(recordingManager: nil)
        }
    }

    func configureSession(recordingManager: RecordingManager?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // Find camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                    ?? AVCaptureDevice.default(for: .video) else {
                Task { @MainActor in
                    self.errorMessage = "No camera found"
                }
                self.captureSession.commitConfiguration()
                return
            }

            // Add video input
            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Failed to access camera: \(error.localizedDescription)"
                }
            }

            // Add audio input (for recording)
            if let microphone = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: microphone)
                    if self.captureSession.canAddInput(audioInput) {
                        self.captureSession.addInput(audioInput)
                    }
                } catch {
                    print("Could not add audio input: \(error.localizedDescription)")
                }
            }

            // Add movie file output for recording
            if let recordingManager {
                Task { @MainActor in
                    recordingManager.configureOutput(for: self.captureSession)
                }
            }

            self.captureSession.commitConfiguration()

            Task { @MainActor in
                self.isConfigured = true
            }
        }
    }

    func startSession() {
        guard permissionStatus == .authorized else {
            Task { await requestPermission() }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                Task { @MainActor in
                    self.isRunning = true
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor in
                    self.isRunning = false
                }
            }
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
