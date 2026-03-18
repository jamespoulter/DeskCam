import SwiftUI
import Combine

@main
struct DeskCamApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .frame(width: 320, height: 500)
                .onAppear {
                    appDelegate.setupPanel(appState: appState)
                }
        } label: {
            Image(systemName: "camera.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: FloatingPanelController?
    private var cancellables = Set<AnyCancellable>()
    private var isSetUp = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Panel is created when AppState becomes available via setupPanel
    }

    @MainActor
    func setupPanel(appState: AppState) {
        guard !isSetUp else { return }
        isSetUp = true

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
    }
}
