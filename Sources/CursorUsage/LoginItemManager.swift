import Foundation
import ServiceManagement

enum LoginItemManager {
    private static let launchAgentLabel = "com.rlimberger.CursorUsage"

    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    /// Stable install location used by the LaunchAgent fallback.
    static var installedAppURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/CursorUsage.app")
    }

    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return FileManager.default.fileExists(atPath: launchAgentURL.path)
        }
    }

    /// Registers open-at-login via SMAppService, with a LaunchAgent fallback.
    @discardableResult
    static func enable() -> String? {
        do {
            try SMAppService.mainApp.register()
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                return status == .requiresApproval
                    ? "Enable CursorUsage in System Settings → General → Login Items."
                    : nil
            }
        } catch {
            // Fall through — common for ad-hoc signed builds.
        }

        do {
            try installLaunchAgent()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    static func disable() -> String? {
        do { try SMAppService.mainApp.unregister() } catch {}

        do {
            try removeLaunchAgent()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Idempotent — called on every launch.
    static func ensureEnabled() {
        let status = SMAppService.mainApp.status
        if status == .enabled || status == .requiresApproval { return }
        if FileManager.default.fileExists(atPath: launchAgentURL.path) { return }
        _ = enable()
    }

    private static func installLaunchAgent() throws {
        // Prefer the installed copy; otherwise pin whatever bundle is running now.
        let running = Bundle.main.bundleURL
        let appURL: URL
        if running.pathExtension == "app" {
            appURL = running
        } else if FileManager.default.fileExists(atPath: installedAppURL.path) {
            appURL = installedAppURL
        } else {
            throw LoginItemError.appNotInstalled
        }

        let appPath = appURL.path
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>-ga</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        let dir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)

        let uid = getuid()
        _ = try? run("/bin/launchctl", ["bootout", "gui/\(uid)/\(launchAgentLabel)"])
        try run("/bin/launchctl", ["bootstrap", "gui/\(uid)", launchAgentURL.path])
    }

    private static func removeLaunchAgent() throws {
        let uid = getuid()
        _ = try? run("/bin/launchctl", ["bootout", "gui/\(uid)/\(launchAgentLabel)"])
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw LoginItemError.commandFailed(output)
        }
        return output
    }
}

private enum LoginItemError: LocalizedError {
    case appNotInstalled
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotInstalled:
            return "Could not find CursorUsage.app to register for login."
        case .commandFailed(let output):
            return output.isEmpty ? "launchctl failed" : output
        }
    }
}
