import SwiftUI
import AVFoundation

// MARK: - Onboarding Step Data

private struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let action: String?
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var appeared = false
    let onComplete: () -> Void

    private let steps = [
        OnboardingStep(
            icon: "camera.fill",
            title: "Welcome to NotchoCam",
            subtitle: "A floating camera overlay for your desktop.\nPerfect for recordings, presentations,\nand video calls.",
            action: nil
        ),
        OnboardingStep(
            icon: "camera.badge.ellipsis",
            title: "Camera Access",
            subtitle: "NotchoCam needs your camera to show\na live preview on your screen.",
            action: "Grant Camera Access"
        ),
        OnboardingStep(
            icon: "mic.badge.plus",
            title: "Microphone Access",
            subtitle: "For recording videos with audio,\nNotchoCam needs microphone access.",
            action: "Grant Mic Access"
        ),
        OnboardingStep(
            icon: "menubar.arrow.up.rectangle",
            title: "Lives in Your Menu Bar",
            subtitle: "Click the camera icon in your menu bar\nto show, hide, and control everything.",
            action: nil
        ),
        OnboardingStep(
            icon: "hand.draw",
            title: "You're All Set",
            subtitle: "Hover over the camera to reveal controls.\nDrag the window anywhere on screen.",
            action: "Get Started"
        )
    ]

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            VStack(spacing: 0) {
                // Illustration zone
                ZStack {
                    GlowCircle(size: 200, opacity: 0.18)
                    StepIllustration(step: currentStep, icon: steps[currentStep].icon)
                        .id("illust-\(currentStep)")
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }
                .frame(height: 230)
                .frame(maxWidth: .infinity)

                // Content zone
                VStack(spacing: 14) {
                    Text(steps[currentStep].title)
                        .font(DSFont.display(24))
                        .foregroundColor(Color.textPrimary)
                        .id("title-\(currentStep)")

                    Text(steps[currentStep].subtitle)
                        .font(DSFont.label(14, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("sub-\(currentStep)")

                    // Permission badges
                    if currentStep == 1 {
                        PillBadge(
                            granted: appState.cameraManager.permissionStatus == .authorized,
                            grantedText: "Camera access granted",
                            pendingText: "Permission not yet granted"
                        )
                        .padding(.top, 6)
                    }
                    if currentStep == 2 {
                        PillBadge(
                            granted: appState.cameraManager.micPermissionStatus == .authorized,
                            grantedText: "Microphone access granted",
                            pendingText: "Permission not yet granted"
                        )
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)

                Spacer()

                // Progress bar
                progressBar
                    .padding(.horizontal, 60)
                    .padding(.bottom, DSSpacing.lg)

                // Control bar
                controlBar
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, DSSpacing.lg)
            }
        }
        .frame(width: 480, height: 520)
        .preferredColorScheme(.dark)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color(hex: "0A0A0A")

            // Warm gradient wash from top
            LinearGradient(
                stops: [
                    .init(color: Color.brand.opacity(0.1), location: 0),
                    .init(color: Color.brand.opacity(0.03), location: 0.3),
                    .init(color: .clear, location: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle noise texture via overlapping radials
            EllipticalGradient(
                colors: [Color.brand.opacity(0.04), .clear],
                center: .init(x: 0.7, y: 0.2)
            )

            EllipticalGradient(
                colors: [Color.white.opacity(0.02), .clear],
                center: .init(x: 0.3, y: 0.8)
            )
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(
                        i <= currentStep
                            ? AnyShapeStyle(LinearGradient(colors: [Color.brand, Color.brandDeep], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.1))
                    )
                    .frame(height: 3)
                    .shadow(color: i == currentStep ? Color.brand.opacity(0.7) : .clear, radius: 6)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep -= 1 }
                }
                .buttonStyle(.ghost)
            }

            Spacer()

            if currentStep == 1 || currentStep == 2 {
                Button("Skip") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep += 1 }
                }
                .font(DSFont.label(13))
                .foregroundColor(Color.textTertiary)
                .padding(.trailing, 8)
            }

            if let actionLabel = steps[currentStep].action {
                Button(actionLabel) {
                    handleAction()
                }
                .buttonStyle(.brand)
            } else {
                Button("Next") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep += 1 }
                }
                .buttonStyle(.brand)
            }
        }
    }

    // MARK: - Actions

    private func handleAction() {
        switch currentStep {
        case 1:
            Task {
                await appState.cameraManager.requestPermission()
                if appState.cameraManager.permissionStatus == .authorized {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep += 1 }
                }
            }
        case 2:
            Task {
                await appState.cameraManager.requestMicPermission()
                if appState.cameraManager.micPermissionStatus == .authorized {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep += 1 }
                }
            }
        case let i where i == steps.count - 1:
            onComplete()
        default:
            break
        }
    }
}

// MARK: - Step Illustration

private struct StepIllustration: View {
    let step: Int
    let icon: String
    @State private var animating = false

    var body: some View {
        ZStack {
            // Outer pulsing rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.brand.opacity(0.12 - Double(ring) * 0.03),
                                Color.brand.opacity(0.04 - Double(ring) * 0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 100 + CGFloat(ring) * 36, height: 100 + CGFloat(ring) * 36)
                    .scaleEffect(animating ? 1.06 : 0.94)
                    .opacity(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 2.5 + Double(ring) * 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(ring) * 0.2),
                        value: animating
                    )
            }

            // Icon backing circle
            ZStack {
                // Soft glow disc behind
                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brand.opacity(0.18), Color.brand.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.brand.opacity(0.5), Color.brand.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.brand.opacity(0.35), radius: 24, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandWarm, Color.brand],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.brand.opacity(0.4), radius: 8)
                    .scaleEffect(animating ? 1.0 : 0.9)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animating
                    )
            }

            // Step-specific particle accents
            stepAccents
        }
        .onAppear { animating = true }
    }

    @ViewBuilder
    private var stepAccents: some View {
        if step == 0 {
            particleRing(count: 5, radius: 62, particleSize: 3, fillOpacity: 0.5)
        } else if step == 4 {
            particleRing(count: 8, radius: 54, particleSize: 2.5, fillOpacity: 0.6)
        }
    }

    private func particleRing(count: Int, radius: CGFloat, particleSize: CGFloat, fillOpacity: Double) -> some View {
        let positions: [(CGFloat, CGFloat)] = (0..<count).map { i in
            let angle: Double = Double(i) * .pi * 2.0 / Double(count)
            return (CGFloat(cos(angle)) * radius, CGFloat(sin(angle)) * radius)
        }
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Color.brand.opacity(fillOpacity))
                    .frame(width: particleSize, height: particleSize)
                    .offset(x: positions[i].0, y: positions[i].1)
                    .scaleEffect(animating ? 1.3 : 0.4)
                    .opacity(animating ? 0.9 : 0.1)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
    }
}
