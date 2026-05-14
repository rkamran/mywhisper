import SwiftUI

@main
struct MyWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(state)
        } label: {
            Image(systemName: state.menuBarSymbol)
                .accessibilityLabel("MyWhisper")
        }
        .menuBarExtraStyle(.menu)
    }
}
