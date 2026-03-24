import SwiftUI

struct FloatingCameraView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var appeared = false

    // Wide shallow notch dimensions — wider and shallower for true notch feel
    private let viewWidth: CGFloat = 620
    private let viewHeight: CGFloat = 300

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
        // Notch mask: flat top + wide shallow semicircle + infinity fade
        .mask(
            NotchFadeMask()
                .frame(width: viewWidth, height: viewHeight)
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
            // Only auto-request permission if onboarding is complete
            // (onboarding handles the permission flow itself)
            if appState.hasCompletedOnboarding {
                Task { await appState.cameraManager.requestPermission() }
            }
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
                    tint: Color.brand,
                    action: { teleprompterState.toggleScrolling() }
                )
                glassButton(
                    icon: "arrow.counterclockwise",
                    tint: Color.brand,
                    action: { teleprompterState.resetPosition() },
                    size: 11
                )
                Spacer()
                glassButton(
                    icon: "xmark",
                    tint: Color.brand,
                    action: { appState.toggleWindow() },
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

// MARK: - Notch Fade Mask

/// A mask that creates a flat-top wide semicircle with a silky smooth gaussian fade.
/// Flat top hugs the menu bar, wide shallow arc curves down, edges dissolve smoothly.
/// Uses 40 concentric layers with an easeOut opacity curve for buttery gradation.
private struct NotchFadeMask: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let archDepth = h * 0.6
            let sideInset = w * 0.03

            // Core arch path — flat top, wide shallow semicircle bottom
            var archPath = Path()
            archPath.move(to: CGPoint(x: sideInset, y: 0))
            archPath.addLine(to: CGPoint(x: w - sideInset, y: 0))
            // Smooth cubic curves for a more natural arc
            archPath.addCurve(
                to: CGPoint(x: w * 0.5, y: archDepth),
                control1: CGPoint(x: w - sideInset, y: archDepth * 0.55),
                control2: CGPoint(x: w * 0.72, y: archDepth)
            )
            archPath.addCurve(
                to: CGPoint(x: sideInset, y: 0),
                control1: CGPoint(x: w * 0.28, y: archDepth),
                control2: CGPoint(x: sideInset, y: archDepth * 0.55)
            )
            archPath.closeSubpath()

            // 40 layers from outermost (faintest) to innermost (solid)
            // Gaussian-like falloff: opacity = e^(-3 * t^2)
            let layerCount = 40
            let maxExpand: CGFloat = 0.5 // how far the fade extends beyond the core

            for i in (0..<layerCount).reversed() {
                let t = CGFloat(i) / CGFloat(layerCount - 1) // 0 = core, 1 = outermost
                let expand = t * maxExpand

                // Gaussian curve for opacity
                let gaussian = exp(-3.0 * Double(t * t))
                let opacity = max(0.0, gaussian)

                let scaleX = 1.0 + expand * 0.6
                let scaleY = 1.0 + expand * 1.4 // fade more aggressively downward

                var transform = CGAffineTransform.identity
                    .translatedBy(x: w * 0.5, y: 0)
                    .scaledBy(x: scaleX, y: scaleY)
                    .translatedBy(x: -w * 0.5, y: 0)

                let scaledPath = archPath.applying(transform)
                context.fill(scaledPath, with: .color(.white.opacity(opacity)))
            }
        }
    }
}
