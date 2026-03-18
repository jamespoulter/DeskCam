import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class TeleprompterState: ObservableObject {
    @Published var text: String = ""
    @Published var scrollSpeed: Double = 30.0
    @Published var isScrolling: Bool = false
    @Published var scrollOffset: CGFloat = 0.0
    @Published var fontSize: CGFloat = 18.0
    @Published var textOpacity: Double = 0.9

    // Timer only runs when scrolling — not a global autoconnect
    private var scrollTimer: Timer?

    func startScrolling() {
        guard !text.isEmpty else { return }
        isScrolling = true
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isScrolling else { return }
                self.scrollOffset += self.scrollSpeed / 60.0
            }
        }
    }

    func stopScrolling() {
        isScrolling = false
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    func toggleScrolling() {
        if isScrolling {
            stopScrolling()
        } else {
            startScrolling()
        }
    }

    func resetPosition() {
        stopScrolling()
        scrollOffset = 0
    }

    func loadFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a text file for the teleprompter"
        panel.treatsFilePackagesAsDirectories = false
        panel.level = .floating

        if let window = NSApp.keyWindow {
            window.close()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            panel.begin { response in
                guard let self, response == .OK, let url = panel.url else { return }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    Task { @MainActor in
                        self.text = content
                        self.resetPosition()
                    }
                }
            }
        }
    }
}
