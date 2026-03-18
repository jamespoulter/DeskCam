import AVFoundation
import SwiftUI

enum VideoFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"

    var fileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        }
    }
}

@MainActor
class RecordingManager: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastRecordingURL: URL?
    @Published var videoFormat: VideoFormat = .mp4
    @Published var outputFolderURL: URL

    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    override init() {
        let moviesDir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let defaultFolder = moviesDir.appendingPathComponent("DeskCam")

        if let savedPath = UserDefaults.standard.string(forKey: "outputFolder"),
           FileManager.default.fileExists(atPath: savedPath) {
            self.outputFolderURL = URL(fileURLWithPath: savedPath)
        } else {
            self.outputFolderURL = defaultFolder
        }

        if let savedFormat = UserDefaults.standard.string(forKey: "videoFormat"),
           let format = VideoFormat(rawValue: savedFormat) {
            self.videoFormat = format
        }

        super.init()

        try? FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
    }

    func startRecording(movieOutput: AVCaptureMovieFileOutput?) {
        guard let movieOutput, !isRecording else { return }

        // Ensure folder exists
        try? FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)

        let filename = generateFilename()
        let fileURL = outputFolderURL.appendingPathComponent(filename)

        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopRecording(movieOutput: AVCaptureMovieFileOutput?) {
        guard isRecording else { return }
        movieOutput?.stopRecording()
        durationTimer?.invalidate()
        durationTimer = nil
    }

    func toggleRecording(movieOutput: AVCaptureMovieFileOutput?) {
        if isRecording {
            stopRecording(movieOutput: movieOutput)
        } else {
            startRecording(movieOutput: movieOutput)
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to save recordings"
        panel.level = .floating

        if let window = NSApp.keyWindow {
            window.close()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            panel.begin { response in
                guard let self, response == .OK, let url = panel.url else { return }
                Task { @MainActor in
                    self.outputFolderURL = url
                    UserDefaults.standard.set(url.path, forKey: "outputFolder")
                }
            }
        }
    }

    func openLastRecording() {
        guard let url = lastRecordingURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openOutputFolder() {
        NSWorkspace.shared.open(outputFolderURL)
    }

    func setFormat(_ format: VideoFormat) {
        videoFormat = format
        UserDefaults.standard.set(format.rawValue, forKey: "videoFormat")
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        return "DeskCam-\(timestamp).\(videoFormat.rawValue)"
    }
}

extension RecordingManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false
            self.lastRecordingURL = outputFileURL
            if let error {
                print("Recording error: \(error.localizedDescription)")
            }
        }
    }
}
