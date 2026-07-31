import Cocoa
import ApplicationServices
import ScreenCaptureKit

struct AppWindow {
    let id: CGWindowID
    let title: String
    let image: NSImage?
    let documentURL: String?
    let bounds: CGRect
    let ownerPID: pid_t
    let isMinimized: Bool
    let isFocused: Bool          // true for the frontmost (main) window of the app
    let axElement: AXUIElement?
    let chromeProfile: ChromeProfile? // Profile info for Chrome windows

    func replacingImage(_ newImage: NSImage?) -> AppWindow {
        AppWindow(
            id: id,
            title: title,
            image: newImage,
            documentURL: documentURL,
            bounds: bounds,
            ownerPID: ownerPID,
            isMinimized: isMinimized,
            isFocused: isFocused,
            axElement: axElement,
            chromeProfile: chromeProfile
        )
    }

    func replacingFocus(_ focused: Bool) -> AppWindow {
        AppWindow(
            id: id,
            title: title,
            image: image,
            documentURL: documentURL,
            bounds: bounds,
            ownerPID: ownerPID,
            isMinimized: isMinimized,
            isFocused: focused,
            axElement: axElement,
            chromeProfile: chromeProfile
        )
    }
}

class WindowFetcher {
    static var isScreenCaptureAuthorized: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    // Detect Chrome profile from window title
    // Chrome adds the profile name to the window title in format: "Page Title - Browser: Profile Name"
    private static func detectChromeProfileFromTitle(title: String, appName: String) -> ChromeProfile? {
        // Only detect for Chrome-based browsers
        guard ChromeProfileFetcher.isChromiumBrowser(appName) else {
            return nil
        }
        
        // Get all available profiles
        let profiles = ChromeProfileFetcher.getProfiles(for: appName)
        guard !profiles.isEmpty else { return nil }
        
        // Chrome window titles have format: "Page Title - Browser Name: Profile Name"
        // Example: "Nova guia - Google Chrome: Gisele"
        
        // Try to extract profile name from title
        let components = title.components(separatedBy: ": ")
        
        if components.count >= 2 {
            // Last component after ": " is typically the profile name
            let possibleProfileName = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Try to find exact match by profile name
            if let matchedProfile = profiles.first(where: { $0.name == possibleProfileName }) {
                print("Matched profile from title '\(title)': \(matchedProfile.name) (\(matchedProfile.id))")
                return matchedProfile
            }
            
            // Try case-insensitive match
            if let matchedProfile = profiles.first(where: { 
                $0.name.lowercased() == possibleProfileName.lowercased() 
            }) {
                print("Matched profile (case-insensitive) from title '\(title)': \(matchedProfile.name) (\(matchedProfile.id))")
                return matchedProfile
            }
        }
        
        // Fallback: Check if any profile name appears anywhere in the title
        for profile in profiles {
            if title.contains(profile.name) {
                print("Matched profile (contains) from title '\(title)': \(profile.name) (\(profile.id))")
                return profile
            }
        }
        
        // If no match found, return Default profile as fallback
        let defaultProfile = profiles.first { $0.id == "Default" }
        if defaultProfile != nil {
            print("No profile match in title '\(title)', using Default profile")
        }
        return defaultProfile
    }
    
    static func getWindows(for appName: String) -> [AppWindow] {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Fetching windows for: \(trimmed)")

        guard let app = RunningAppResolver.application(matchingDockTitle: trimmed) else {
            print("App \(trimmed) not found in running applications.")
            return []
        }

        let pid = app.processIdentifier
        let resolvedName: String = {
            if let n = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return n }
            return trimmed
        }()
        print("Found App PID: \(pid) (resolved name: \(resolvedName))")

        return getAllWindowsViaAccessibility(for: pid, appName: resolvedName)
    }
    
    private static func getAllWindowsViaAccessibility(for pid: pid_t, appName: String) -> [AppWindow] {
        let appRef = AXUIElementCreateApplication(pid)
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
            print("Could not get AX windows, falling back to CGWindowList")
            return getVisibleWindowsFallback(for: pid, appName: appName)
        }
        
        // Quartz metadata gives us real window IDs without reading window pixels.
        var cgWindowsMap = getCGWindowsMap(for: pid)
        
        var windows: [AppWindow] = []
        var windowIndex = 0
        
        for axWindow in axWindows {
            // Check if minimized
            var minimizedValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedValue)
            let isMinimized = (minimizedValue as? Bool) ?? false
            
            // Get window title
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String) ?? ""
            
            // Skip windows without title (usually internal/hidden windows)
            // But keep minimized windows even without title
            if title.isEmpty && !isMinimized { continue }
            
            // Get position and size
            var positionValue: AnyObject?
            var sizeValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue)
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)
            
            var position = CGPoint.zero
            var size = CGSize(width: 800, height: 600)
            
            if let positionValue = positionValue, CFGetTypeID(positionValue) == AXValueGetTypeID() {
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
            }
            if let sizeValue = sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            }
            
            // Skip very small windows
            if size.width < 50 || size.height < 50 { continue }
            
            let bounds = CGRect(origin: position, size: size)
            
            // Check if this is the main (frontmost) window of the app
            var mainValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, kAXMainAttribute as CFString, &mainValue)
            let isMain = (mainValue as? Bool) ?? false

            windowIndex += 1
            let displayTitle = title.isEmpty ? "Window \(windowIndex)" : title
            let cgWindow = takeBestCGWindow(bounds: bounds, title: title, cgWindows: &cgWindowsMap)
            let windowID = cgWindow?.id ?? fallbackWindowID(
                pid: pid,
                title: displayTitle,
                bounds: bounds,
                index: windowIndex
            )

            var documentValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, kAXDocumentAttribute as CFString, &documentValue)
            let documentURL = (documentValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Detect Chrome profile from this specific window's title
            let chromeProfile = detectChromeProfileFromTitle(title: displayTitle, appName: appName)
            
            print("Added window: \(displayTitle) (minimized: \(isMinimized), profile: \(chromeProfile?.name ?? "none"))")
            
            windows.append(AppWindow(
                id: windowID,
                title: displayTitle,
                image: nil,
                documentURL: documentURL?.isEmpty == false ? documentURL : nil,
                bounds: bounds,
                ownerPID: pid,
                isMinimized: isMinimized,
                isFocused: isMain,
                axElement: axWindow,
                chromeProfile: chromeProfile
            ))
        }
        
        print("Total windows: \(windows.count)")
        return windows
    }
    
    private static func getCGWindowsMap(for pid: pid_t) -> [(id: CGWindowID, bounds: CGRect, title: String)] {
        guard let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var result: [(id: CGWindowID, bounds: CGRect, title: String)] = []
        
        for info in windowListInfo {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            guard let idNum = info[kCGWindowNumber as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }
            
            let title = info[kCGWindowName as String] as? String ?? ""
            result.append((id: CGWindowID(idNum), bounds: bounds, title: title))
        }
        
        return result
    }
    
    private static func takeBestCGWindow(
        bounds: CGRect,
        title: String,
        cgWindows: inout [(id: CGWindowID, bounds: CGRect, title: String)]
    ) -> (id: CGWindowID, bounds: CGRect, title: String)? {
        // Find matching CG window - prioritize title match, then position match
        var bestMatchIndex: Int? = nil
        var bestMatchScore = 0
        
        for (index, cg) in cgWindows.enumerated() {
            var score = 0
            
            // Title match is highest priority
            if !title.isEmpty && !cg.title.isEmpty && cg.title == title {
                score += 100
            }
            
            // Position match (within tolerance)
            let posMatch = abs(cg.bounds.origin.x - bounds.origin.x) < 50 &&
                           abs(cg.bounds.origin.y - bounds.origin.y) < 50
            if posMatch {
                score += 50
            }
            
            // Size match
            let sizeMatch = abs(cg.bounds.width - bounds.width) < 50 &&
                            abs(cg.bounds.height - bounds.height) < 50
            if sizeMatch {
                score += 25
            }
            
            if score > bestMatchScore {
                bestMatchScore = score
                bestMatchIndex = index
            }
        }
        
        // Remove the match so duplicate titles cannot reuse the same Quartz window.
        if let index = bestMatchIndex, bestMatchScore > 0 {
            return cgWindows.remove(at: index)
        }
        
        return nil
    }

    private static func fallbackWindowID(
        pid: pid_t,
        title: String,
        bounds: CGRect,
        index: Int
    ) -> CGWindowID {
        var hasher = Hasher()
        hasher.combine(pid)
        hasher.combine(title)
        hasher.combine(Int(bounds.origin.x.rounded()))
        hasher.combine(Int(bounds.origin.y.rounded()))
        hasher.combine(index)
        return CGWindowID(truncatingIfNeeded: UInt(bitPattern: hasher.finalize()))
    }
    
    private static func getVisibleWindowsFallback(for pid: pid_t, appName: String) -> [AppWindow] {
        guard let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [AppWindow] = []
        
        for info in windowListInfo {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            guard let idNum = info[kCGWindowNumber as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  bounds.width >= 50, bounds.height >= 50
            else { continue }
            
            let title = info[kCGWindowName as String] as? String ?? "Window"
            let windowID = CGWindowID(idNum)
            // Detect Chrome profile from this specific window's title
            let chromeProfile = detectChromeProfileFromTitle(title: title, appName: appName)
            
            // First window in CGWindowList is frontmost
            let isFocused = windows.isEmpty
            windows.append(AppWindow(
                id: windowID,
                title: title,
                image: nil,
                documentURL: nil,
                bounds: bounds,
                ownerPID: pid,
                isMinimized: false,
                isFocused: isFocused,
                axElement: nil,
                chromeProfile: chromeProfile
            ))
        }
        
        return windows
    }

    /// Captures optional previews with the modern macOS API. This is never called
    /// unless the user has already granted Screen Recording permission.
    @MainActor
    static func capturePreviews(for windows: [AppWindow]) async -> [CGWindowID: NSImage] {
        guard isScreenCaptureAuthorized else { return [:] }

        let candidates = windows.filter { !$0.isMinimized }
        guard !candidates.isEmpty else { return [:] }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: false
            )
            let shareableByID = Dictionary(
                uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) }
            )
            var previews: [CGWindowID: NSImage] = [:]

            for window in candidates {
                guard !Task.isCancelled else { break }
                guard let shareableWindow = matchingShareableWindow(
                    for: window,
                    directMatches: shareableByID,
                    allWindows: content.windows
                ) else {
                    print("No ScreenCaptureKit window match for: \(window.title) [\(window.id)]")
                    continue
                }

                let configuration = SCStreamConfiguration()
                let sourceWidth = max(window.bounds.width, 1)
                let sourceHeight = max(window.bounds.height, 1)
                let targetWidth = min(sourceWidth, 640)
                configuration.width = Int(targetWidth.rounded())
                configuration.height = Int((targetWidth * sourceHeight / sourceWidth).rounded())
                configuration.showsCursor = false

                let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
                for attempt in 0..<3 {
                    guard !Task.isCancelled else { break }
                    do {
                        let cgImage = try await SCScreenshotManager.captureImage(
                            contentFilter: filter,
                            configuration: configuration
                        )
                        previews[window.id] = NSImage(
                            cgImage: cgImage,
                            size: NSSize(width: cgImage.width, height: cgImage.height)
                        )
                        break
                    } catch {
                        print(
                            "Preview attempt \(attempt + 1) failed for \(window.title): "
                                + error.localizedDescription
                        )
                        if attempt < 2 {
                            try? await Task.sleep(
                                nanoseconds: UInt64(90_000_000 * (attempt + 1))
                            )
                        }
                    }
                }
            }

            return previews
        } catch {
            print("Could not load window previews: \(error.localizedDescription)")
            return [:]
        }
    }

    private static func matchingShareableWindow(
        for window: AppWindow,
        directMatches: [CGWindowID: SCWindow],
        allWindows: [SCWindow]
    ) -> SCWindow? {
        if let direct = directMatches[window.id] {
            return direct
        }

        let candidates = allWindows.filter {
            $0.owningApplication?.processID == window.ownerPID && $0.windowLayer == 0
        }
        if candidates.count == 1 {
            return candidates[0]
        }

        return candidates.max { lhs, rhs in
            shareableMatchScore(lhs, for: window) < shareableMatchScore(rhs, for: window)
        }
    }

    private static func shareableMatchScore(_ candidate: SCWindow, for window: AppWindow) -> CGFloat {
        var score: CGFloat = 0
        if let title = candidate.title, !title.isEmpty, title == window.title {
            score += 100
        }

        let frame = candidate.frame
        let sizeDelta = abs(frame.width - window.bounds.width) + abs(frame.height - window.bounds.height)
        let positionDelta = abs(frame.minX - window.bounds.minX) + abs(frame.minY - window.bounds.minY)
        score += max(0, 60 - sizeDelta)
        score += max(0, 40 - positionDelta / 2)
        return score
    }
    
    static func activateWindow(window: AppWindow) {
        print("Activating window: \(window.title) (minimized: \(window.isMinimized))")
        
        let app = NSRunningApplication(processIdentifier: window.ownerPID)
        
        // Use the stored AXUIElement directly - this is the most reliable method
        if let axElement = window.axElement {
            if window.isMinimized {
                // Unminimize first
                let unminResult = AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                print("Unminimize result: \(unminResult == .success ? "success" : "failed")")
            }
            
            // Activate the app
            app?.activate(options: [.activateAllWindows])
            
            // Raise the specific window
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            print("Raise result: \(raiseResult == .success ? "success" : "failed")")
            
            // Also try to set it as main/focused window
            let appRef = AXUIElementCreateApplication(window.ownerPID)
            AXUIElementSetAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, axElement)
        } else {
            // Fallback: just activate the app (rare case - shouldn't happen with new code)
            print("Warning: No AXUIElement stored, just activating app")
            app?.activate(options: [.activateAllWindows])
        }
    }
    
    static func closeWindow(window: AppWindow) {
        print("Closing window: \(window.title)")
        
        guard let axElement = window.axElement else {
            print("Warning: No AXUIElement stored, cannot close window")
            return
        }
        
        // Get the close button and press it
        var closeButton: AnyObject?
        let result = AXUIElementCopyAttributeValue(axElement, kAXCloseButtonAttribute as CFString, &closeButton)
        
        if result == .success, let button = closeButton {
            let pressResult = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            print("Close result: \(pressResult == .success ? "success" : "failed")")
        } else {
            print("Could not find close button")
        }
    }
    
    static func minimizeWindow(window: AppWindow) {
        print("Minimizing window: \(window.title)")
        
        guard let axElement = window.axElement else {
            print("Warning: No AXUIElement stored, cannot minimize window")
            return
        }
        
        // Toggle minimize state
        let newMinimizedState = !window.isMinimized
        let result = AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, newMinimizedState as CFTypeRef)
        print("Minimize result: \(result == .success ? "success" : "failed")")
    }
    
    static func toggleFullscreen(window: AppWindow) {
        print("Maximizing window (zoom): \(window.title)")
        
        guard let axElement = window.axElement else {
            print("Warning: No AXUIElement stored, cannot maximize window")
            return
        }
        
        // First, activate the window
        let app = NSRunningApplication(processIdentifier: window.ownerPID)
        app?.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        
        // Get the visible frame (screen minus dock and menu bar)
        guard let screen = NSScreen.main else {
            print("Could not get main screen")
            return
        }
        
        let visibleFrame = screen.visibleFrame
        let screenHeight = screen.frame.height
        
        // Convert position to AX coordinates (top-left origin)
        // visibleFrame.origin is in Cocoa coordinates (bottom-left origin)
        // AX uses top-left origin
        let axY = screenHeight - visibleFrame.origin.y - visibleFrame.height
        
        // Set position (top-left corner of visible area)
        var position = CGPoint(x: visibleFrame.origin.x, y: axY)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            let posResult = AXUIElementSetAttributeValue(axElement, kAXPositionAttribute as CFString, positionValue)
            print("Position set result: \(posResult == .success ? "success" : "failed")")
        }
        
        // Set size to fill visible area
        var size = CGSize(width: visibleFrame.width, height: visibleFrame.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let sizeResult = AXUIElementSetAttributeValue(axElement, kAXSizeAttribute as CFString, sizeValue)
            print("Size set result: \(sizeResult == .success ? "success" : "failed")")
        }
        
        print("Maximized to: \(visibleFrame)")
    }
    
    static func killProcess(window: AppWindow) {
        print("Killing process for window: \(window.title)")
        
        let pid = window.ownerPID
        
        // Use kill signal to terminate the process
        let result = kill(pid, SIGTERM)
        
        if result == 0 {
            print("Process \(pid) terminated successfully")
        } else {
            // If SIGTERM fails, try SIGKILL (force)
            print("SIGTERM failed, trying SIGKILL")
            let forceResult = kill(pid, SIGKILL)
            if forceResult == 0 {
                print("Process \(pid) force killed successfully")
            } else {
                print("Failed to kill process \(pid)")
            }
        }
    }
    
}
