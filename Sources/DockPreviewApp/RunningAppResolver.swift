import AppKit
import Foundation

/// Maps Dock icon titles (Accessibility `AXTitle`) to `NSRunningApplication`.
/// Dock labels often differ from `localizedName` (e.g. generic "Electron" for dev or misconfigured bundles).
enum RunningAppResolver {

    private static let knownDockTitleToBundleID: [String: String] = [
        "whatsapp": "net.whatsapp.WhatsApp",
        "whatsapp desktop": "net.whatsapp.WhatsApp",
        "telegram": "ru.keepcoder.Telegram",
        "vscode": "com.microsoft.VSCode",
        "visual studio code": "com.microsoft.VSCode",
        "code": "com.microsoft.VSCode",
    ]

    static func application(
        matchingDockTitle iconTitle: String,
        runningApps: [NSRunningApplication] = NSWorkspace.shared.runningApplications
    ) -> NSRunningApplication? {
        let trimmed = iconTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowerTitle = trimmed.lowercased()

        if let app = runningApps.first(where: { $0.localizedName == trimmed }) {
            return app
        }

        if let app = runningApps.first(where: { ($0.localizedName ?? "").lowercased() == lowerTitle }) {
            return app
        }

        if let app = runningApps.first(where: { $0.executableURL?.lastPathComponent == trimmed }) {
            return app
        }
        if let app = runningApps.first(where: { $0.executableURL?.lastPathComponent.lowercased() == lowerTitle }) {
            return app
        }

        if let bundleID = knownDockTitleToBundleID[lowerTitle],
           let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            return app
        }

        if lowerTitle == "electron" {
            let candidates = electronShellCandidates(in: runningApps)
            if let chosen = disambiguateElectronCandidates(candidates) {
                print(
                    "[RunningAppResolver] Dock 'Electron' → \(chosen.localizedName ?? "?") pid=\(chosen.processIdentifier) bundle=\(chosen.bundleIdentifier ?? "?")"
                )
                return chosen
            }
        }

        if let app = runningApps.first(where: {
            guard let name = $0.localizedName?.lowercased() else { return false }
            return name.contains(lowerTitle) || lowerTitle.contains(name)
        }) {
            return app
        }

        if let app = runningApps.first(where: { $0.localizedName?.contains(trimmed) == true }) {
            return app
        }

        return nil
    }

    private static func electronShellCandidates(in runningApps: [NSRunningApplication]) -> [NSRunningApplication] {
        runningApps.filter { app in
            if app.bundleIdentifier?.hasPrefix("com.apple") == true { return false }
            let exe = app.executableURL?.lastPathComponent ?? ""
            if exe == "Electron" || exe.lowercased() == "electron" { return true }
            let path = app.bundleURL?.path.lowercased() ?? ""
            if path.contains("/electron.app/") || path.hasSuffix("/electron.app") { return true }
            let bid = app.bundleIdentifier?.lowercased() ?? ""
            if bid.contains("electron") { return true }
            return false
        }
    }

    private static func disambiguateElectronCandidates(_ candidates: [NSRunningApplication]) -> NSRunningApplication? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates.first }
        if let front = NSWorkspace.shared.frontmostApplication,
           let match = candidates.first(where: { $0.processIdentifier == front.processIdentifier }) {
            return match
        }
        if let active = candidates.first(where: { $0.isActive }) { return active }
        print("[RunningAppResolver] Multiple Electron shells (\(candidates.count)); using pid \(candidates[0].processIdentifier)")
        return candidates.first
    }
}
