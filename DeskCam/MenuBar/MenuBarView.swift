import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.accentColor)
                Text("DeskCam")
                    .font(.headline)
                Spacer()
                Button(action: { appState.toggleWindow() }) {
                    Image(systemName: appState.isWindowVisible ? "eye.fill" : "eye.slash")
                        .foregroundColor(appState.isWindowVisible ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(appState.isWindowVisible ? "Hide Camera" : "Show Camera")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    RecordingSection(recording: appState.recordingManager, appState: appState)
                    Divider()
                    TeleprompterSection(state: appState.teleprompterState)
                    Divider()
                    ControlsSection(state: appState.teleprompterState)
                    Divider()
                    SettingsSection(appState: appState)
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Teleprompter Section

struct TeleprompterSection: View {
    @ObservedObject var state: TeleprompterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Teleprompter", systemImage: "text.alignleft")
                    .font(.subheadline.bold())
                Spacer()
                Button("Load File") {
                    state.loadFile()
                }
                .controlSize(.small)
            }

            TextEditor(text: $state.text)
                .font(.system(size: 12))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if state.text.isEmpty {
                        Text("Paste or type your script here...")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

// MARK: - Controls Section

struct ControlsSection: View {
    @ObservedObject var state: TeleprompterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Controls", systemImage: "slider.horizontal.3")
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                Button(action: { state.toggleScrolling() }) {
                    Label(
                        state.isScrolling ? "Pause" : "Play",
                        systemImage: state.isScrolling ? "pause.fill" : "play.fill"
                    )
                }
                .controlSize(.small)

                Button(action: { state.resetPosition() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(Int(state.scrollSpeed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $state.scrollSpeed, in: 10...100, step: 5)
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Font Size: \(Int(state.fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $state.fontSize, in: 12...48, step: 2)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection: View {
    @ObservedObject var appState: AppState
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var teleprompterState: TeleprompterState
    @ObservedObject var loginItemManager: LoginItemManager

    init(appState: AppState) {
        self.appState = appState
        self.cameraManager = appState.cameraManager
        self.teleprompterState = appState.teleprompterState
        self.loginItemManager = appState.loginItemManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Settings", systemImage: "gear")
                .font(.subheadline.bold())

            // Camera picker
            if cameraManager.availableCameras.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: Binding(
                        get: { cameraManager.selectedCameraID },
                        set: { cameraManager.switchCamera(to: $0) }
                    )) {
                        ForEach(cameraManager.availableCameras, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
            }

            Toggle("Mirror Camera", isOn: $appState.isMirrored)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 4) {
                Text("Window Opacity: \(Int(appState.windowOpacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $appState.windowOpacity, in: 0.3...1.0, step: 0.05)
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Text Opacity: \(Int(teleprompterState.textOpacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $teleprompterState.textOpacity, in: 0.3...1.0, step: 0.05)
                    .controlSize(.small)
            }

            Toggle("Launch at Startup", isOn: Binding(
                get: { loginItemManager.isEnabled },
                set: { _ in loginItemManager.toggle() }
            ))
            .controlSize(.small)
        }
    }
}

// MARK: - Recording Section

struct RecordingSection: View {
    @ObservedObject var recording: RecordingManager
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recording", systemImage: "record.circle")
                    .font(.subheadline.bold())
                Spacer()
                if recording.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text(recording.formattedDuration)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.red)
                    }
                }
            }

            // Record button
            Button(action: { appState.toggleRecording() }) {
                Label(
                    recording.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: recording.isRecording ? "stop.fill" : "record.circle"
                )
                .foregroundColor(recording.isRecording ? .red : .primary)
            }
            .controlSize(.small)

            // Format picker
            HStack {
                Text("Format:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { recording.videoFormat },
                    set: { recording.setFormat($0) }
                )) {
                    Text(".mp4").tag(VideoFormat.mp4)
                    Text(".mov").tag(VideoFormat.mov)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // Output folder
            HStack {
                Text(recording.outputFolderURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change") {
                    recording.chooseOutputFolder()
                }
                .controlSize(.mini)
            }

            // Last recording actions
            if recording.lastRecordingURL != nil {
                HStack(spacing: 8) {
                    Button(action: { recording.openLastRecording() }) {
                        Label("Open Last", systemImage: "play.circle")
                    }
                    .controlSize(.mini)
                    Button(action: { recording.openOutputFolder() }) {
                        Label("Show Folder", systemImage: "folder")
                    }
                    .controlSize(.mini)
                }
            }
        }
    }
}
