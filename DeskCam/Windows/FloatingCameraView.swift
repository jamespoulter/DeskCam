import SwiftUI

struct FloatingCameraView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var appeared = false

    // Wide notch-inspired dimensions
    private let viewWidth: CGFloat = 550
    private let viewHeight: CGFloat = 340

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(
                session: appState.cameraManager.captureSession,
                isMirrored: appState.isMirrored
            )

            // Liquid glass tint — subtle frosted overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.15)

            // Dark vignette — elliptical, wider than tall
            EllipticalGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.15),
                    .black.opacity(0.5),
                    .black.opacity(0.8)
                ],
                center: .init(x: 0.5, y: 0.4),
                startRadiusFraction: 0.15,
                endRadiusFraction: 0.55
            )

            // Strong top fade — merges with notch/menu bar
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.9), location: 0.0),
                    .init(color: .black.opacity(0.5), location: 0.06),
                    .init(color: .black.opacity(0.15), location: 0.15),
                    .init(color: .clear, location: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle inner glow — light refraction at edges
            EllipticalGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .white.opacity(0.04), location: 0.45),
                    .init(color: .white.opacity(0.08), location: 0.5),
                    .init(color: .white.opacity(0.03), location: 0.55),
                    .init(color: .clear, location: 0.6)
                ],
                center: .init(x: 0.5, y: 0.4)
            )

            // Camera permission / error states
            CameraStatusOverlay(cameraManager: appState.cameraManager)

            // Teleprompter overlay
            if !appState.teleprompterState.text.isEmpty {
                TeleprompterView(state: appState.teleprompterState)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white, location: 0.2),
                                .init(color: .white, location: 0.65),
                                .init(color: .clear, location: 0.85)
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
                    .transition(.opacity)
            }
        }
        .frame(width: viewWidth, height: viewHeight)
        // Wide horizontal elliptical fade — emulates the notch silhouette
        .mask(
            EllipticalGradient(
                stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: 0.25),
                    .init(color: .white.opacity(0.9), location: 0.35),
                    .init(color: .white.opacity(0.6), location: 0.48),
                    .init(color: .white.opacity(0.2), location: 0.62),
                    .init(color: .white.opacity(0.05), location: 0.75),
                    .init(color: .clear, location: 0.85)
                ],
                center: .init(x: 0.5, y: 0.35)
            )
            // Stretch wider to match the notch's horizontal aspect
            .scaleEffect(x: 1.3, y: 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isHovering = hovering
            }
            if hovering { scheduleHideControls() }
        }
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            Task { await appState.cameraManager.requestPermission() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var readingLineIndicator: some View {
        VStack {
            Spacer().frame(height: viewHeight * 0.38)
            HStack(spacing: 6) {
                capsuleLine
                Circle().fill(.white.opacity(0.3)).frame(width: 3, height: 3)
                capsuleLine
            }
            .padding(.horizontal, 80)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var capsuleLine: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, .white.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 0.5)
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
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulse ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                Text(recording.formattedDuration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(Capsule())
            .padding(.top, 20)
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
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.5))
                Text("Camera Access Required")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Button("Open Settings") { cameraManager.openSystemSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        } else if let error = cameraManager.errorMessage {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
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
            HStack(spacing: 12) {
                glassButton(
                    icon: recordingManager.isRecording ? "stop.fill" : "record.circle",
                    tint: .red,
                    action: { appState.toggleRecording() }
                )
                glassButton(
                    icon: teleprompterState.isScrolling ? "pause.fill" : "play.fill",
                    action: { teleprompterState.toggleScrolling() }
                )
                glassButton(
                    icon: "arrow.counterclockwise",
                    action: { teleprompterState.resetPosition() },
                    size: 11
                )
                Spacer()
                glassButton(
                    icon: "xmark",
                    action: {
                        appState.isWindowVisible = false
                        appState.cameraManager.stopSession()
                    },
                    size: 11
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                // Glass-like control bar
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .padding(.horizontal, 12)
            )
            .padding(.bottom, 8)
        }
    }

    private func glassButton(icon: String, tint: Color = .white, action: @escaping () -> Void, size: CGFloat = 13) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
