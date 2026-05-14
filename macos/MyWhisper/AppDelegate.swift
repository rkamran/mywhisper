import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let openSetupNotification = Notification.Name("MyWhisper.openSetup")
    private var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSetup),
            name: Self.openSetupNotification,
            object: nil
        )

        Task { @MainActor in
            await AppState.shared.bootstrap()
            if !AppState.shared.isFullyConfigured {
                showSetup()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in self.showSetup() }
        return true
    }

    @objc private func handleOpenSetup() {
        Task { @MainActor in self.showSetup() }
    }

    @MainActor
    func showSetup() {
        if let window = setupWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(
            rootView: SetupView().environmentObject(AppState.shared)
        )
        let window = NSWindow(contentViewController: host)
        window.title = "MyWhisper"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        setupWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
