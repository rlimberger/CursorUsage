import AppKit
import SwiftUI

@main
struct CursorUsageApp: App {
    @State private var model = UsageViewModel()
    @State private var cursorMonitor = CursorRunningMonitor()
    /// Separate from the monitor so cmd-dragging the extra out doesn’t desync process state.
    @State private var isMenuBarInserted = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: $isMenuBarInserted) {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: MenuBarGlyph.image(
                cursorPercent: model.cursorPercentText,
                otherPercent: model.otherPercentText,
                resetCountdown: model.resetCountdownText
            ))
        }
        .menuBarExtraStyle(.window)
        .onChange(of: cursorMonitor.isCursorRunning, initial: true) { _, running in
            syncCursorVisibility(running)
        }
    }

    private func syncCursorVisibility(_ running: Bool) {
        isMenuBarInserted = running
        if running {
            model.start()
            Task { await model.refresh() }
        } else {
            model.stop()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LoginItemManager.ensureEnabled()
    }
}
