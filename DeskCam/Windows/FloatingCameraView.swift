import SwiftUI

struct FloatingCameraView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(
                session: appState.cameraManager.captureSession,
                isMirrored: appState.isMirrored
            )
            // Dark vignette for text readability
            .overlay(
                RadialGradient(
                    colors: [
                        .clear,
                        .clear,
                        .black.opacity(0.25),
                        .black.opacity(0.65)
                    ],
                    center: .init(x: 0.5, y: 0.3),
                    startRadius: 80,
                    endRadius: 300
                )
            )
            // Strong top fade to blend with notch/menu bar
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.85), location: 0.0),
                        .init(color: .black.opacity(0.4), location: 0.08),
                        .init(color: .clear, location: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Camera permission / error states
            CameraStatusOverlay(cameraManager: appState.cameraManager)

            // Teleprompter overlay
            if !appState.teleprompterState.text.isEmpty {
                TeleprompterView(state: appState.teleprompterState)
                    // Mask teleprompter so text fades at top and bottom
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white, location: 0.15),
                                .init(color: .white, location: 0.7),
                                .init(color: .clear, location: 0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Recording indicator
            if appState.recordingManager.isRecording {
                RecordingIndicator(recording: appState.recordingManager)
            }

            // Reading line
            if appState.teleprompterState.isScrolling {
                readingLineIndicator
            }

            // Hover controls
            if isHovering {
                ControlOverlay(appState: appState)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 420, height: 520)
        // Soft elliptical fade — the entire edge dissolves to transparent
        .mask(
            RadialGradient(
                stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.3),
                    .init(color: .white.opacity(0.85), location: 0.45),
                    .init(color: .white.opacity(0.5), location: 0.6),
                    .init(color: .white.opacity(0.15), location: 0.75),
                    .init(color: .clear, location: 0.9)
                ],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 300
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
            if hovering { scheduleHideControls() }
        }
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            Task { await appState.cameraManager.requestPermission() }
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    private var readingLineIndicator: some View {
        VStack {
            Spacer().frame(height: 170)
            HStack(spacing: 8) {
                capsuleLine
                Circle().fill(.white.opacity(0.35)).frame(width: 4, height: 4)
                capsuleLine
            }
            .padding(.horizontal, 50)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var capsuleLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) { isHovering = false }
            }
        }
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    @ObservedObject var recording: RecordingManager
    @State private var pulse = false

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                Text(recording.formattedDuration)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.4))
            .clipShape(Capsule())
            .padding(.top, 30)
            Spacer()
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Camera Status Overlay

struct CameraStatusOverlay: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        if cameraManager.permissionStatus != .authorized {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.6))
                Text("Camera Access Required")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Button("Open Settings") { cameraManager.openSystemSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        } else if let error = cameraManager.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Control Overlay

struct ControlOverlay: View {
    @ObservedObject var teleprompterState: TeleprompterState
    @ObservedObject var recordingManager: RecordingManager
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.teleprompterState = appState.teleprompterState
        self.recordingManager = appState.recordingManager
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                controlButton(
                    icon: recordingManager.isRecording ? "stop.fill" : "record.circle",
                    tint: .red,
                    action: { appState.toggleRecording() }
                )
                controlButton(
                    icon: teleprompterState.isScrolling ? "pause.fill" : "play.fill",
                    action: { teleprompterState.toggleScrolling() }
                )
                controlButton(
                    icon: "arrow.counterclockwise",
                    action: { teleprompterState.resetPosition() },
                    size: 12
                )
                Spacer()
                controlButton(
                    icon: "xmark",
                    action: {
                        appState.isWindowVisible = false
                        appState.cameraManager.stopSession()
                    },
                    size: 12
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func controlButton(icon: String, tint: Color = .white, action: @escaping () -> Void, size: CGFloat = 14) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
