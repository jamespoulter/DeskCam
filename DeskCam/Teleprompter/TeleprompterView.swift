import SwiftUI

struct TeleprompterView: View {
    @ObservedObject var state: TeleprompterState

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Text starts from below the visible area and scrolls up
                Spacer()
                    .frame(height: geometry.size.height)

                Text(state.text)
                    .font(.system(size: state.fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(state.textOpacity))
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: geometry.size.width - 40, alignment: .center)
                    .padding(.horizontal, 20)

                Spacer()
                    .frame(height: geometry.size.height)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -state.scrollOffset)
        }
        .clipped()
        .allowsHitTesting(false)
        .onReceive(state.scrollTimer) { _ in
            if state.isScrolling {
                state.scrollOffset += state.scrollSpeed / 60.0
            }
        }
    }
}
