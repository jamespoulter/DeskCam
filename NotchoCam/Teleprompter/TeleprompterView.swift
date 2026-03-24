import SwiftUI

struct TeleprompterView: View {
    @ObservedObject var state: TeleprompterState

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height)

                Text(state.text)
                    .font(.system(size: state.fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(state.textOpacity))
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    // Narrow column to stay inside the visible notch arch
                    .frame(width: min(geometry.size.width * 0.55, 260), alignment: .center)
                    .frame(maxWidth: .infinity)

                Spacer()
                    .frame(height: geometry.size.height)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -state.scrollOffset)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
