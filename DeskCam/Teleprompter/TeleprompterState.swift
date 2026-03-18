import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class TeleprompterState: ObservableObject {
    @Published var text: String = ""
    @Published var scrollSpeed: Double = 30.0 // points per second
    @Published var isScrolling: Bool = false
    @Published var scrollOffset: CGFloat = 0.0
    @Published var fontSize: CGFloat = 18.0
    @Published var textOpacity: Double = 0.9

    // 60fps timer that drives the scroll
    let scrollTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    func startScrolling() {
        guard !text.isEmpty else { return }
        isScrolling = true
    }

    func stopScrolling() {
        isScrolling = false
    }

    func toggleScrolling() {
        if isScrolling {
            stopScrolling()
        } else {
            startScrolling()
        }
    }

    func resetPosition() {
        scrollOffset = 0
        isScrolling = false
    }

    func loadFile() {
        // Create panel on main thread, then run modal after a short delay
        // to let the MenuBarExtra popover dismiss
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a text file for the teleprompter"
        panel.treatsFilePackagesAsDirectories = false
        panel.level = .floating

        // Close the menu bar popover first
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
