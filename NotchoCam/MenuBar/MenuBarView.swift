import SwiftUI

// MARK: - Tab Enum

private enum MenuTab: String, CaseIterable {
    case camera = "Camera"
    case teleprompter = "Teleprompter"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .teleprompter: return "text.alignleft"
        case .settings: return "gear"
        }
    }
}

// MARK: - Main View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: MenuTab = .camera

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            // Tab bar
            tabBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider()

            // Tab content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .camera:
                        CameraTabView(appState: appState)
                    case .teleprompter:
                        TeleprompterTabView(state: appState.teleprompterState)
                    case .settings:
                        SettingsTabView(appState: appState)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(DSFont.label(11))
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                Spacer()
                Text("v1.0")
                    .font(DSFont.mono(9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.15))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.brand.opacity(0.3), lineWidth: 0.5))
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.brand)
            }
            Text("NotchoCam")
                .font(DSFont.heading(14))
            Spacer()
            Button(action: { appState.toggleWindow() }) {
                Image(systemName: appState.isWindowVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appState.isWindowVisible ? Color.brand : .secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(appState.isWindowVisible ? Color.brand.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        Circle().stroke(appState.isWindowVisible ? Color.brand.opacity(0.3) : .clear, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help(appState.isWindowVisible ? "Hide Camera" : "Show Camera")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func tabButton(_ tab: MenuTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(tab.rawValue)
                    .font(DSFont.label(10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundColor(isActive ? Color.brand : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.brand.opacity(0.12) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? Color.brand.opacity(0.2) : .clear, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Wrapper

private struct CardSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Camera Tab

private struct CameraTabView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var recordingManager: RecordingManager
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.cameraManager = appState.cameraManager
        self.recordingManager = appState.recordingManager
    }

    var body: some View {
        VStack(spacing: 10) {
            // Camera picker
            if cameraManager.availableCameras.count > 1 {
                CardSection {
                    Label("Source", systemImage: "video")
                        .font(DSFont.label(10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
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

            // Recording
            CardSection {
                HStack {
                    Label("Recording", systemImage: "record.circle")
                        .font(DSFont.label(10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if recordingManager.isRecording {
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 5, height: 5)
                            Text(recordingManager.formattedDuration)
                                .font(DSFont.mono(10))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.1)))
                    }
                }

                // Record button
                Button(action: { appState.toggleRecording() }) {
                    HStack(spacing: 6) {
                        Image(systemName: recordingManager.isRecording ? "stop.fill" : "record.circle")
                        Text(recordingManager.isRecording ? "Stop Recording" : "Start Recording")
                    }
                    .font(DSFont.label(12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        recordingManager.isRecording
                            ? AnyShapeStyle(Color.red.gradient)
                            : AnyShapeStyle(LinearGradient(colors: [Color.brand, Color.brandDeep], startPoint: .top, endPoint: .bottom))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: (recordingManager.isRecording ? Color.red : Color.brand).opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                // Format + folder row
                HStack {
                    Picker("", selection: Binding(
                        get: { recordingManager.videoFormat },
                        set: { recordingManager.setFormat($0) }
                    )) {
                        Text(".mp4").tag(VideoFormat.mp4)
                        Text(".mov").tag(VideoFormat.mov)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)

                    Spacer()

                    Button(action: { recordingManager.chooseOutputFolder() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "folder").font(.system(size: 9))
                            Text(recordingManager.outputFolderURL.lastPathComponent)
                                .font(DSFont.label(10))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if recordingManager.lastRecordingURL != nil {
                    HStack(spacing: 8) {
                        Button(action: { recordingManager.openLastRecording() }) {
                            Label("Open Last", systemImage: "play.circle")
                                .font(DSFont.label(10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color.brand)

                        Button(action: { recordingManager.openOutputFolder() }) {
                            Label("Show Folder", systemImage: "folder")
                                .font(DSFont.label(10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Teleprompter Tab

private struct TeleprompterTabView: View {
    @ObservedObject var state: TeleprompterState

    var body: some View {
        VStack(spacing: 10) {
            // Script
            CardSection {
                HStack {
                    Label("Script", systemImage: "doc.text")
                        .font(DSFont.label(10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button(action: { state.loadFile() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.badge.plus").font(.system(size: 9))
                            Text("Load File").font(DSFont.label(10))
                        }
                        .foregroundColor(Color.brand)
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $state.text)
                    .font(DSFont.label(12))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.background.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
                    .overlay(alignment: .topLeading) {
                        if state.text.isEmpty {
                            Text("Paste or type your script here...")
                                .foregroundColor(.secondary.opacity(0.5))
                                .font(DSFont.label(12))
                                .padding(10)
                                .allowsHitTesting(false)
                        }
                    }
            }

            // Controls
            CardSection {
                Label("Playback", systemImage: "play.circle")
                    .font(DSFont.label(10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    Button(action: { state.toggleScrolling() }) {
                        HStack(spacing: 4) {
                            Image(systemName: state.isScrolling ? "pause.fill" : "play.fill")
                            Text(state.isScrolling ? "Pause" : "Play")
                        }
                        .font(DSFont.label(11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [Color.brand, Color.brandDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.brand.opacity(0.25), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)

                    Button(action: { state.resetPosition() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(DSFont.label(11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.quaternary.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                brandSlider(label: "Speed", value: $state.scrollSpeed, range: 10...100, step: 5, display: "\(Int(state.scrollSpeed))")
                brandSlider(label: "Font Size", value: $state.fontSize, range: 12...48, step: 2, display: "\(Int(state.fontSize))pt")
            }
        }
    }

    private func brandSlider(label: String, value: Binding<some BinaryFloatingPoint & Strideable>, range: ClosedRange<Double>, step: Double, display: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(DSFont.label(10)).foregroundColor(.secondary)
                Spacer()
                Text(display).font(DSFont.mono(10)).foregroundColor(Color.brand)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = .init($0) }
            ), in: range, step: step)
                .controlSize(.small)
                .tint(Color.brand)
        }
    }
}

// MARK: - Settings Tab

private struct SettingsTabView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var teleprompterState: TeleprompterState
    @ObservedObject var loginItemManager: LoginItemManager

    init(appState: AppState) {
        self.appState = appState
        self.teleprompterState = appState.teleprompterState
        self.loginItemManager = appState.loginItemManager
    }

    var body: some View {
        VStack(spacing: 10) {
            CardSection {
                Label("Display", systemImage: "paintbrush")
                    .font(DSFont.label(10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                settingsToggle(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                              label: "Mirror Camera",
                              isOn: $appState.isMirrored)

                brandSlider(label: "Window Opacity", value: $appState.windowOpacity, range: 0.3...1.0, step: 0.05, display: "\(Int(appState.windowOpacity * 100))%")
                brandSlider(label: "Text Opacity", value: $teleprompterState.textOpacity, range: 0.3...1.0, step: 0.05, display: "\(Int(teleprompterState.textOpacity * 100))%")
            }

            CardSection {
                Label("System", systemImage: "gearshape")
                    .font(DSFont.label(10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                settingsToggle(icon: "sunrise",
                              label: "Launch at Startup",
                              isOn: Binding(
                                get: { loginItemManager.isEnabled },
                                set: { _ in loginItemManager.toggle() }
                              ))
            }
        }
    }

    private func settingsToggle(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.brand)
                .frame(width: 16)
            Text(label)
                .font(DSFont.label(12))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Color.brand)
        }
    }

    private func brandSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, display: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(DSFont.label(10)).foregroundColor(.secondary)
                Spacer()
                Text(display).font(DSFont.mono(10)).foregroundColor(Color.brand)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
                .tint(Color.brand)
        }
    }
}
