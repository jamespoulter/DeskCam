import SwiftUI
import AppKit

@MainActor
class FloatingPanelController: NSObject, ObservableObject {
    private var panel: NSPanel?
    private weak var appState: AppState?

    func createPanel(appState: AppState) {
        self.appState = appState

        let contentView = NSHostingView(
            rootView: FloatingCameraView()
                .environmentObject(appState)
        )

        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 500

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // No system shadow — the radial fade IS the edge
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.contentView = contentView
        panel.alphaValue = CGFloat(appState.windowOpacity)

        positionBelowNotch(panel)

        self.panel = panel
    }

    func showPanel() {
        panel?.orderFront(nil)
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    func updateOpacity(_ opacity: Double) {
        panel?.alphaValue = CGFloat(opacity)
    }

    private func positionBelowNotch(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y

        // Center horizontally, top edge touching the menu bar bottom
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - menuBarHeight - panel.frame.height + 10
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
