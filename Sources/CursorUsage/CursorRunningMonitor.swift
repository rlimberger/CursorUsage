import AppKit
import Observation

/// Tracks whether the Cursor IDE is running so the menu-bar item can hide/show.
@MainActor
@Observable
final class CursorRunningMonitor {
    static let cursorBundleID = "com.todesktop.230313mzl4w4u92"

    var isCursorRunning = false

    @ObservationIgnored private var launchedObserver: NSObjectProtocol?
    @ObservationIgnored private var terminatedObserver: NSObjectProtocol?

    init() {
        refresh()
        let workspace = NSWorkspace.shared.notificationCenter

        launchedObserver = workspace.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            Task { @MainActor in
                if Self.isCursor(app) { self?.isCursorRunning = true }
            }
        }

        terminatedObserver = workspace.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            Task { @MainActor in
                guard let self, Self.isCursor(app) else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        isCursorRunning = NSWorkspace.shared.runningApplications.contains { Self.isCursor($0) }
    }

    private static func isCursor(_ app: NSRunningApplication) -> Bool {
        if let bundleID = app.bundleIdentifier {
            if bundleID == cursorBundleID { return true }
            // Main IDE only — ignore helpers / agent workers.
            if bundleID == "com.todesktop.230313mzl4w4u92" { return true }
        }
        // Bundle path check is more reliable than process name.
        if let url = app.bundleURL, url.lastPathComponent == "Cursor.app" {
            return true
        }
        return false
    }
}
