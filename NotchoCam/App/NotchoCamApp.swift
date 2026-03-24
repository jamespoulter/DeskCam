import SwiftUI
import Combine

@main
struct NotchoCamApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .frame(width: 340, height: 520)
                .onAppear {
                    appDelegate.setupPanel(appState: appState)
                }
        } label: {
            Image(systemName: "camera.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panelController: FloatingPanelController?
    private var welcomeWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var isSetUp = false
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Welcome window is shown once AppState is available via setupPanel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Prevent welcome window close from quitting the app
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === welcomeWindow {
            welcomeWindow = nil
        }
    }

    @MainActor
    func setupPanel(appState: AppState) {
        guard !isSetUp else { return }
        isSetUp = true
        self.appState = appState

        let controller = FloatingPanelController()
        controller.createPanel(appState: appState)
        self.panelController = controller

        // Observe window visibility
        appState.$isWindowVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak controller] visible in
                if visible {
                    controller?.showPanel()
                } else {
                    controller?.hidePanel()
                }
            }
            .store(in: &cancellables)

        // Observe opacity
        appState.$windowOpacity
            .receive(on: DispatchQueue.main)
            .sink { [weak controller] opacity in
                controller?.updateOpacity(opacity)
            }
            .store(in: &cancellables)

        // Show welcome on first launch
        if !appState.hasCompletedOnboarding {
            showWelcome(appState: appState)
        }
    }

    @MainActor
    func showWelcome(appState: AppState) {
        guard welcomeWindow == nil else { return }

        let welcomeView = WelcomeView { [weak self] in
            appState.completeOnboarding()
            appState.toggleWindow()
            self?.welcomeWindow?.orderOut(nil)
            self?.welcomeWindow = nil
        }
        .environmentObject(appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.black
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: welcomeView)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.welcomeWindow = window
    }
}
