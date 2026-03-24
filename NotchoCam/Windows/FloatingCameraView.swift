import SwiftUI

struct FloatingCameraView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var appeared = false

    private let viewWidth: CGFloat = 480
    private let cameraHeight: CGFloat = 200
    private let controlsHeight: CGFloat = 60
    private let totalHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            // Camera region — masked by NotchFadeMask
            ZStack {
                CameraPreviewView(
                    session: appState.cameraManager.captureSession,
                    isMirrored: appState.isMirrored
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.15)

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

                EllipticalGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: .white.opacity(0.04), location: 0.45),
                        .init(color: .white.opacity(0.08), location: 0.5),
                        .init(color: .white.opacity(0.03), location: 0.55),
                        .init(color: .clear, location: 0.6)
                    ],
                    center: .init(x: 0.5, y: 0.35)
                )

                CameraStatusOverlay(cameraManager: appState.cameraManager)

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

                if appState.recordingManager.isRecording {
                    RecordingIndicator(recording: appState.recordingManager)
                }

                if appState.teleprompterState.isScrolling {
                    readingLineIndicator
                }
            }
            .frame(width: viewWidth, height: cameraHeight)
            .mask(
                NotchFadeMask()
                    .frame(width: viewWidth, height: cameraHeight)
            )

            // Pop-out controls — outside the mask, spring cascade on hover
            PopOutControlBar(appState: appState, isHovering: isHovering)
                .frame(width: viewWidth, height: controlsHeight)
        }
        .frame(width: viewWidth, height: totalHeight)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isHovering = hovering
            }
            if hovering { scheduleHideControls() }
        }
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            if appState.hasCompletedOnboarding {
                Task { await appState.cameraManager.requestPermission() }
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var readingLineIndicator: some View {
        VStack {
            Spacer().frame(height: cameraHeight * 0.38)
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
                    .buttonStyle(.brand)
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

// MARK: - Pop-Out Control Bar

struct PopOutControlBar: View {
    @ObservedObject var teleprompterState: TeleprompterState
    @ObservedObject var recordingManager: RecordingManager
    let appState: AppState
    let isHovering: Bool

    init(appState: AppState, isHovering: Bool) {
        self.appState = appState
        self.teleprompterState = appState.teleprompterState
        self.recordingManager = appState.recordingManager
        self.isHovering = isHovering
    }

    var body: some View {
        ZStack {
            // Frosted glass pill background
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .frame(width: 240, height: 44)
                .opacity(isHovering ? 1 : 0)
                .scaleEffect(isHovering ? 1.0 : 0.85)
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.75),
                    value: isHovering
                )

            // Buttons with staggered spring cascade
            HStack(spacing: 18) {
                cascadeButton(index: 0) {
                    controlButton(
                        icon: recordingManager.isRecording ? "stop.fill" : "record.circle",
                        tint: .red,
                        size: 34,
                        iconSize: 14,
                        action: { appState.toggleRecording() }
                    )
                }
                cascadeButton(index: 1) {
                    controlButton(
                        icon: teleprompterState.isScrolling ? "pause.fill" : "play.fill",
                        tint: Color.brand,
                        size: 30,
                        iconSize: 12,
                        action: { teleprompterState.toggleScrolling() }
                    )
                }
                cascadeButton(index: 2) {
                    controlButton(
                        icon: "arrow.counterclockwise",
                        tint: Color.brand,
                        size: 30,
                        iconSize: 11,
                        action: { teleprompterState.resetPosition() }
                    )
                }
                cascadeButton(index: 3) {
                    controlButton(
                        icon: "xmark",
                        tint: .white.opacity(0.6),
                        size: 30,
                        iconSize: 11,
                        action: { appState.toggleWindow() }
                    )
                }
            }
        }
        .offset(y: isHovering ? -4 : -16)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75),
            value: isHovering
        )
    }

    @ViewBuilder
    private func cascadeButton<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(isHovering ? 1 : 0)
            .scaleEffect(isHovering ? 1.0 : 0.5)
            .offset(y: isHovering ? 0 : 10)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.65)
                    .delay(Double(index) * 0.05),
                value: isHovering
            )
    }

    private func controlButton(icon: String, tint: Color, size: CGFloat, iconSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 8)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(tint)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notch Shape

/// The notch arch: flat top with rounded corners, wide shallow semicircle bottom.
private struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let archDepth = h * 0.72
        let sideInset = w * 0.08
        let cornerR = w * 0.05

        var path = Path()
        path.move(to: CGPoint(x: sideInset, y: cornerR))
        path.addQuadCurve(
            to: CGPoint(x: sideInset + cornerR, y: 0),
            control: CGPoint(x: sideInset, y: 0)
        )
        path.addLine(to: CGPoint(x: w - sideInset - cornerR, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w - sideInset, y: cornerR),
            control: CGPoint(x: w - sideInset, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: archDepth),
            control1: CGPoint(x: w - sideInset, y: archDepth * 0.5),
            control2: CGPoint(x: w * 0.68, y: archDepth)
        )
        path.addCurve(
            to: CGPoint(x: sideInset, y: cornerR),
            control1: CGPoint(x: w * 0.32, y: archDepth),
            control2: CGPoint(x: sideInset, y: archDepth * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Notch Fade Mask

/// Uses real gaussian blur on a solid shape for perfectly smooth edge fade.
/// Two layers: a tight inner blur (crisp core) + a wider outer blur (soft halo).
private struct NotchFadeMask: View {
    var body: some View {
        ZStack {
            // Outer halo — wide soft fade
            NotchShape()
                .fill(.white)
                .blur(radius: 20)

            // Inner core — crisp with slight edge softening
            NotchShape()
                .fill(.white)
                .blur(radius: 8)
        }
        .compositingGroup()
    }
}
