import Cocoa
import ApplicationServices

struct AppWindow {
    let id: CGWindowID
    let title: String
    let image: NSImage?
    let bounds: CGRect
    let ownerPID: pid_t
    let isMinimized: Bool
    let axElement: AXUIElement?
}

class WindowFetcher {
    // Cache for last successful window captures (key: "pid-title")
    private static var imageCache: [String: NSImage] = [:]
    private static let maxCacheSize = 50 // Limit cache to 50 images
    
    private static func cacheKey(pid: pid_t, title: String) -> String {
        return "\(pid)-\(title)"
    }
    
    private static func cleanupCacheIfNeeded() {
        if imageCache.count > maxCacheSize {
            // Remove oldest entries (simple approach: remove half)
            let keysToRemove = Array(imageCache.keys.prefix(imageCache.count / 2))
            for key in keysToRemove {
                imageCache.removeValue(forKey: key)
            }
            print("Cache cleaned: removed \(keysToRemove.count) entries")
        }
    }
    
    static func clearCache(for pid: pid_t) {
        let keysToRemove = imageCache.keys.filter { $0.hasPrefix("\(pid)-") }
        for key in keysToRemove {
            imageCache.removeValue(forKey: key)
        }
    }
    
    static func getWindows(for appName: String) -> [AppWindow] {
        print("Fetching windows for: \(appName)")
        let runningApps = NSWorkspace.shared.runningApplications
        
        guard let app = runningApps.first(where: { $0.localizedName == appName }) else {
            print("App \(appName) not found in running applications.")
            if let looseMatch = runningApps.first(where: { $0.localizedName?.contains(appName) == true }) {
                print("Found loose match: \(looseMatch.localizedName ?? "")")
                return getWindows(for: looseMatch.localizedName ?? "")
            }
            return []
        }
        
        let pid = app.processIdentifier
        print("Found App PID: \(pid)")
        
        // Use Accessibility API as primary source - more reliable for activation
        return getAllWindowsViaAccessibility(for: pid, app: app)
    }
    
    private static func getAllWindowsViaAccessibility(for pid: pid_t, app: NSRunningApplication) -> [AppWindow] {
        let appRef = AXUIElementCreateApplication(pid)
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
            print("Could not get AX windows, falling back to CGWindowList")
            return getVisibleWindowsFallback(for: pid)
        }
        
        // Also get CGWindowList for capturing images of visible windows
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
            
            // Generate a unique ID - use index to ensure uniqueness
            let windowID = CGWindowID(pid) * 1000 + CGWindowID(windowIndex)
            windowIndex += 1
            
            let displayTitle = title.isEmpty ? "Window \(windowIndex)" : title
            let cacheKeyStr = cacheKey(pid: pid, title: displayTitle)
            
            // Get image - pass mutable cgWindowsMap to remove used windows
            var image: NSImage?
            if isMinimized {
                image = getMinimizedWindowImage(app: app, axWindow: axWindow)
            } else {
                // Try to find matching CG window for image capture
                image = findAndCaptureImage(bounds: bounds, title: title, cgWindows: &cgWindowsMap)
                
                if let capturedImage = image {
                    // Cache successful capture
                    imageCache[cacheKeyStr] = capturedImage
                    cleanupCacheIfNeeded()
                } else if let cachedImage = imageCache[cacheKeyStr] {
                    // Use cached image as fallback
                    image = cachedImage
                    print("Using cached image for: \(displayTitle)")
                }
            }
            
            print("Added window: \(displayTitle) (minimized: \(isMinimized), hasImage: \(image != nil))")
            
            windows.append(AppWindow(
                id: windowID,
                title: displayTitle,
                image: image,
                bounds: bounds,
                ownerPID: pid,
                isMinimized: isMinimized,
                axElement: axWindow
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
    
    private static func findAndCaptureImage(bounds: CGRect, title: String, cgWindows: inout [(id: CGWindowID, bounds: CGRect, title: String)]) -> NSImage? {
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
        
        // If we found a match, capture and remove from list to prevent reuse
        if let index = bestMatchIndex, bestMatchScore > 0 {
            let cg = cgWindows[index]
            cgWindows.remove(at: index) // Remove so it won't be matched again
            return captureWindowImage(windowID: cg.id, bounds: cg.bounds)
        }
        
        return nil
    }
    
    private static func getVisibleWindowsFallback(for pid: pid_t) -> [AppWindow] {
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
            let cacheKeyStr = cacheKey(pid: pid, title: title)
            
            var image = captureWindowImage(windowID: windowID, bounds: bounds)
            
            if let capturedImage = image {
                // Cache successful capture
                imageCache[cacheKeyStr] = capturedImage
                cleanupCacheIfNeeded()
            } else if let cachedImage = imageCache[cacheKeyStr] {
                // Use cached image as fallback
                image = cachedImage
                print("Using cached image for: \(title)")
            }
            
            windows.append(AppWindow(id: windowID, title: title, image: image, bounds: bounds, ownerPID: pid, isMinimized: false, axElement: nil))
        }
        
        return windows
    }
    
    private static func getMinimizedWindowImage(app: NSRunningApplication, axWindow: AXUIElement) -> NSImage? {
        // Try to get the minimized window's dock image (Dock stores a preview)
        // Unfortunately, this isn't directly accessible via public APIs
        // Fall back to app icon with a minimized overlay
        
        guard let appIcon = app.icon else { return nil }
        
        // Create a composite image with minimized indicator
        let size = NSSize(width: 128, height: 80)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw a dark background
        NSColor(white: 0.2, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 8, yRadius: 8).fill()
        
        // Draw app icon centered
        let iconSize: CGFloat = 48
        let iconRect = NSRect(
            x: (size.width - iconSize) / 2,
            y: (size.height - iconSize) / 2 + 8,
            width: iconSize,
            height: iconSize
        )
        appIcon.draw(in: iconRect)
        
        // Draw "minimized" indicator
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        let text = "Minimized"
        let textRect = NSRect(x: 0, y: 4, width: size.width, height: 16)
        text.draw(in: textRect, withAttributes: attrs)
        
        image.unlockFocus()
        
        return image
    }
    
    private static func captureWindowImage(windowID: CGWindowID, bounds: CGRect) -> NSImage? {
        // Create image of the specific window
        let imageOption: CGWindowListOption = [.optionIncludingWindow]
        let imageBounds = CGRect.null // Capture full window
        
        guard let cgImage = CGWindowListCreateImage(imageBounds, imageOption, windowID, [.boundsIgnoreFraming, .bestResolution]) else {
            print("Failed to capture image for window \(windowID)")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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
            app?.activate(options: [.activateIgnoringOtherApps])
            
            // Raise the specific window
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            print("Raise result: \(raiseResult == .success ? "success" : "failed")")
            
            // Also try to set it as main/focused window
            let appRef = AXUIElementCreateApplication(window.ownerPID)
            AXUIElementSetAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, axElement)
        } else {
            // Fallback: just activate the app (rare case - shouldn't happen with new code)
            print("Warning: No AXUIElement stored, just activating app")
            app?.activate(options: [.activateIgnoringOtherApps])
        }
    }
    
    static func closeWindow(window: AppWindow) {
        print("Closing window: \(window.title)")
        
        guard let axElement = window.axElement else {
            print("Warning: No AXUIElement stored, cannot close window")
            return
        }
        
        // Remove from cache
        let cacheKeyStr = cacheKey(pid: window.ownerPID, title: window.title)
        imageCache.removeValue(forKey: cacheKeyStr)
        
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
        app?.activate(options: [.activateIgnoringOtherApps])
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
        
        // Clear cache for this process
        clearCache(for: pid)
        
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
    
    // MARK: - Spotify Integration
    
    static func isSpotify(_ appName: String) -> Bool {
        return appName.lowercased() == "spotify"
    }
    
    /// Toggle like for current Spotify song using CGEvent sent directly to Spotify process
    static func spotifyToggleLike() {
        print("Toggling Spotify like via CGEvent to PID")
        
        // Find Spotify PID
        let runningApps = NSWorkspace.shared.runningApplications
        guard let spotify = runningApps.first(where: { $0.localizedName?.lowercased() == "spotify" }) else {
            print("Spotify not running")
            return
        }
        
        let spotifyPID = spotify.processIdentifier
        print("Spotify PID: \(spotifyPID)")
        
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Failed to create event source")
            return
        }
        
        // Key code for 'B' is 11
        let keyCode: CGKeyCode = 11
        
        // Create key down event with Option+Shift
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            print("Failed to create key down event")
            return
        }
        keyDown.flags = [.maskAlternate, .maskShift]  // Option + Shift
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("Failed to create key up event")
            return
        }
        keyUp.flags = [.maskAlternate, .maskShift]
        
        // Post events directly to Spotify's PID
        keyDown.postToPid(spotifyPID)
        keyUp.postToPid(spotifyPID)
        
        print("Sent Option+Shift+B directly to Spotify PID \(spotifyPID)")
    }
}
