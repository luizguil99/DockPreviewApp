import Foundation
import AppKit

struct ChromeProfile: Identifiable {
    let id: String           // Directory name (e.g., "Default", "Profile 1")
    let name: String         // Display name from preferences
    let imagePath: String?   // Path to profile avatar image
    let profilePath: String  // Full path to profile directory
    
    var avatarImage: NSImage? {
        // Try to load Google Account avatar first
        if let googleAvatarPath = findGoogleAvatar() {
            return NSImage(contentsOfFile: googleAvatarPath)
        }
        
        // Fallback to default Chrome avatar
        if let imagePath = imagePath {
            return NSImage(contentsOfFile: imagePath)
        }
        
        return nil
    }
    
    private func findGoogleAvatar() -> String? {
        // Google account avatars are stored in the profile directory
        let avatarPaths = [
            "\(profilePath)/Google Profile Picture.png",
            "\(profilePath)/Google Profile.png",
            "\(profilePath)/Avatars/avatar_generic.png"
        ]
        
        for path in avatarPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
}

class ChromeProfileFetcher {
    // Supported Chrome-based browsers
    static let supportedBrowsers: [(name: String, path: String, bundleID: String)] = [
        ("Google Chrome", "Google/Chrome", "com.google.Chrome"),
        ("Google Chrome Canary", "Google/Chrome Canary", "com.google.Chrome.canary"),
        ("Chromium", "Chromium", "org.chromium.Chromium"),
        ("Microsoft Edge", "Microsoft Edge", "com.microsoft.edgemac"),
        ("Brave Browser", "BraveSoftware/Brave-Browser", "com.brave.Browser"),
        ("Vivaldi", "Vivaldi", "com.vivaldi.Vivaldi"),
        ("Opera", "com.operasoftware.Opera", "com.operasoftware.Opera"),
        ("Arc", "Arc/User Data", "company.thebrowser.Browser"),
    ]
    
    static func isChromiumBrowser(_ appName: String) -> Bool {
        return getBrowserInfo(for: appName) != nil
    }
    
    static func getBrowserInfo(for appName: String) -> (name: String, path: String, bundleID: String)? {
        let lowerName = appName.lowercased().trimmingCharacters(in: .whitespaces)
        
        return supportedBrowsers.first { browser in
            let browserLower = browser.name.lowercased()
            
            // Exact match only
            return browserLower == lowerName
        }
    }
    
    static func getProfiles(for appName: String) -> [ChromeProfile] {
        guard let browserInfo = getBrowserInfo(for: appName) else {
            return []
        }
        
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let chromeDataPath = applicationSupport.appendingPathComponent(browserInfo.path)
        
        print("Looking for profiles in: \(chromeDataPath.path)")
        
        guard FileManager.default.fileExists(atPath: chromeDataPath.path) else {
            print("Chrome data path not found")
            return []
        }
        
        var profiles: [ChromeProfile] = []
        
        // Read Local State file to get profile info
        let localStatePath = chromeDataPath.appendingPathComponent("Local State")
        
        if let localStateData = try? Data(contentsOf: localStatePath),
           let json = try? JSONSerialization.jsonObject(with: localStateData) as? [String: Any],
           let profileInfo = json["profile"] as? [String: Any],
           let infoCache = profileInfo["info_cache"] as? [String: Any] {
            
            print("Found \(infoCache.count) profiles in Local State")
            
            for (profileDir, info) in infoCache {
                guard let profileData = info as? [String: Any] else { continue }
                
                let name = profileData["name"] as? String ?? profileData["gaia_name"] as? String ?? profileDir
                let avatarIcon = profileData["avatar_icon"] as? String
                let profilePath = chromeDataPath.appendingPathComponent(profileDir).path
                
                // Get avatar image path
                var imagePath: String? = nil
                if let avatarIcon = avatarIcon, avatarIcon.hasPrefix("chrome://theme/IDR_PROFILE_AVATAR_") {
                    // Extract avatar number and find corresponding file
                    if let avatarNum = avatarIcon.components(separatedBy: "_").last {
                        let avatarFile = chromeDataPath.appendingPathComponent("Avatars/avatar_\(avatarNum).png")
                        if FileManager.default.fileExists(atPath: avatarFile.path) {
                            imagePath = avatarFile.path
                        }
                    }
                }
                
                profiles.append(ChromeProfile(
                    id: profileDir,
                    name: name,
                    imagePath: imagePath,
                    profilePath: profilePath
                ))
                
                print("Found profile: \(name) (\(profileDir))")
            }
        } else {
            // Fallback: scan directories for profiles
            print("Falling back to directory scan")
            
            let profileDirs = ["Default"] + (1...20).map { "Profile \($0)" }
            
            for dir in profileDirs {
                let profilePath = chromeDataPath.appendingPathComponent(dir)
                let prefsPath = profilePath.appendingPathComponent("Preferences")
                
                guard FileManager.default.fileExists(atPath: prefsPath.path) else { continue }
                
                var name = dir
                
                // Try to read profile name from Preferences
                if let prefsData = try? Data(contentsOf: prefsPath),
                   let prefs = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any] {
                    
                    // Check various places for the profile name
                    if let accountInfo = prefs["account_info"] as? [[String: Any]],
                       let firstAccount = accountInfo.first,
                       let fullName = firstAccount["full_name"] as? String {
                        name = fullName
                    } else if let profile = prefs["profile"] as? [String: Any],
                              let profileName = profile["name"] as? String {
                        name = profileName
                    }
                }
                
                profiles.append(ChromeProfile(
                    id: dir,
                    name: name,
                    imagePath: nil,
                    profilePath: profilePath.path
                ))
                
                print("Found profile (fallback): \(name) (\(dir))")
            }
        }
        
        // Sort: Default first, then alphabetically by name
        return profiles.sorted { p1, p2 in
            if p1.id == "Default" { return true }
            if p2.id == "Default" { return false }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }
    }
    
    static func openNewWindow(for appName: String, profile: ChromeProfile) {
        guard let browserInfo = getBrowserInfo(for: appName) else {
            print("Browser info not found for: \(appName)")
            return
        }
        
        print("Opening \(browserInfo.name) with profile: \(profile.name) (\(profile.id))")
        
        // Run in background to not block UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Method 1: Use 'open' command with full app path
            // open -na "/Applications/Google Chrome.app" --args --profile-directory="Profile 1" --new-window
            let appFullPath = "/Applications/\(browserInfo.name).app"
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [
                "-na", appFullPath,
                "--args",
                "--profile-directory=\(profile.id)",
                "--new-window"
            ]
            
            do {
                try task.run()
                print("Launched: open -na \"\(appFullPath)\" --args --profile-directory=\(profile.id) --new-window")
            } catch {
                print("Error with open command: \(error)")
                // Try direct executable launch
                launchDirectly(browserInfo: browserInfo, profile: profile)
            }
        }
    }
    
    private static func launchDirectly(browserInfo: (name: String, path: String, bundleID: String), profile: ChromeProfile) {
        // Find the actual executable inside the app bundle
        let appBundlePath = "/Applications/\(browserInfo.name).app"
        let executableName: String
        
        // Chrome's executable is "Google Chrome", not the bundle name
        switch browserInfo.bundleID {
        case "com.google.Chrome":
            executableName = "Google Chrome"
        case "com.google.Chrome.canary":
            executableName = "Google Chrome Canary"
        case "com.microsoft.edgemac":
            executableName = "Microsoft Edge"
        case "com.brave.Browser":
            executableName = "Brave Browser"
        default:
            executableName = browserInfo.name
        }
        
        let execPath = "\(appBundlePath)/Contents/MacOS/\(executableName)"
        
        guard FileManager.default.fileExists(atPath: execPath) else {
            print("Executable not found at: \(execPath)")
            return
        }
        
        print("Trying direct launch: \(execPath)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: execPath)
        task.arguments = ["--profile-directory=\(profile.id)", "--new-window"]
        
        do {
            try task.run()
            print("Direct launch successful")
        } catch {
            print("Direct launch failed: \(error)")
        }
    }
}
