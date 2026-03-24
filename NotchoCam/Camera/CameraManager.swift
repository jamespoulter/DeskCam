import AVFoundation
import SwiftUI

@MainActor
class CameraManager: ObservableObject {
    @Published var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var micPermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published var isRunning: Bool = false
    @Published var errorMessage: String?
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraID: String = ""

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.notchocam.session")
    private(set) var isConfigured = false
    private(set) var movieOutput: AVCaptureMovieFileOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?

    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        permissionStatus = granted ? .authorized : .denied
        if granted {
            refreshCameraList()
        }
    }

    func requestMicPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        micPermissionStatus = granted ? .authorized : .denied
    }

    func refreshCameraList() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices
        print("[CameraManager] Found \(availableCameras.count) cameras:")
        for cam in availableCameras {
            print("  - \(cam.localizedName) [\(cam.uniqueID)] suspended=\(cam.isSuspended)")
        }
        if selectedCameraID.isEmpty, let first = availableCameras.first {
            selectedCameraID = first.uniqueID
        }
    }

    func switchCamera(to deviceID: String) {
        guard deviceID != selectedCameraID || !isConfigured else { return }
        guard let device = availableCameras.first(where: { $0.uniqueID == deviceID }) else {
            print("[CameraManager] Device not found: \(deviceID)")
            return
        }

        selectedCameraID = deviceID
        print("[CameraManager] Switching to: \(device.localizedName) (suspended=\(device.isSuspended))")

        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.captureSession.beginConfiguration()

            // Remove current video input
            if let current = self.currentVideoInput {
                self.captureSession.removeInput(current)
            }

            // Add new video input
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    Task { @MainActor in
                        self.currentVideoInput = newInput
                        self.errorMessage = nil
                    }
                    print("[CameraManager] Successfully added input for \(device.localizedName)")
                } else {
                    print("[CameraManager] canAddInput returned false for \(device.localizedName)")
                    Task { @MainActor in
                        self.errorMessage = "Cannot use \(device.localizedName)"
                    }
                }
            } catch {
                print("[CameraManager] Error switching camera: \(error)")
                Task { @MainActor in
                    self.errorMessage = "Failed to switch camera: \(error.localizedDescription)"
                }
            }

            self.captureSession.commitConfiguration()

            // Restart session if it was running
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                Task { @MainActor in
                    self.isRunning = true
                }
            }
        }
    }

    func configureSession() {
        guard !isConfigured else { return }
        refreshCameraList()

        let targetDevice = availableCameras.first(where: { $0.uniqueID == selectedCameraID })
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
            ?? AVCaptureDevice.default(for: .video)

        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // 1. Add video input
            guard let camera = targetDevice else {
                Task { @MainActor in
                    self.errorMessage = "No camera found"
                }
                self.captureSession.commitConfiguration()
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                    Task { @MainActor in
                        self.currentVideoInput = videoInput
                        self.selectedCameraID = camera.uniqueID
                    }
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Failed to access camera: \(error.localizedDescription)"
                }
            }

            // 2. Add audio input
            if let microphone = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: microphone)
                    if self.captureSession.canAddInput(audioInput) {
                        self.captureSession.addInput(audioInput)
                        Task { @MainActor in
                            self.currentAudioInput = audioInput
                        }
                    }
                } catch {
                    print("Could not add audio input: \(error.localizedDescription)")
                }
            }

            // 3. Add movie file output
            let output = AVCaptureMovieFileOutput()
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)

                if let connection = output.connection(with: .video) {
                    output.setOutputSettings(
                        [AVVideoCodecKey: AVVideoCodecType.hevc],
                        for: connection
                    )
                }
            }

            self.captureSession.commitConfiguration()

            Task { @MainActor in
                self.movieOutput = output
                self.isConfigured = true
            }
        }
    }

    func startSession() {
        guard permissionStatus == .authorized else {
            Task { await requestPermission() }
            return
        }

        if !isConfigured {
            configureSession()
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
