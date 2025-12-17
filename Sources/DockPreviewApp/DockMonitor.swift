import Cocoa
import ApplicationServices
import SwiftUI 
import Combine

struct DockIcon {
    let title: String
    let frame: CGRect
    let element: AXUIElement
}

class DockMonitor: ObservableObject {
    @Published var hoveredIcon: DockIcon?
    private var icons: [DockIcon] = []
    private var timer: Timer?
    private let dockBundleID = "com.apple.dock"
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastActiveAppBundleID: String?
    private var pendingHideAppBundleID: String?

    init() {
        startMonitoring()
        setupEventTap()
        setupActiveAppTracking()
    }
    
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    func startMonitoring() {
        // Update icons every 2 seconds to catch layout changes
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateIcons()
        }
        // Check mouse position frequently
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
        updateIcons()
    }
    
    private func setupActiveAppTracking() {
        // Track which app is active BEFORE clicking on dock
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                if app.bundleIdentifier != "com.apple.dock" {
                    self?.lastActiveAppBundleID = app.bundleIdentifier
                }
            }
        }
        lastActiveAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    private func setupEventTap() {
        // Create an event tap to intercept clicks BEFORE they reach the Dock
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        // Use a C function pointer wrapper
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let monitor = Unmanaged<DockMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEventTap(proxy: proxy, type: type, event: event)
        }
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap - need Accessibility permissions")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap setup complete")
    }
    
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Get mouse location from the event
        let mouseLoc = event.location
        guard let screenHeight = NSScreen.main?.frame.height else {
            return Unmanaged.passRetained(event)
        }
        
        // CGEvent location is already in top-left coordinates (Quartz)
        let mousePointTopLeft = mouseLoc
        
        // Check if click is on a dock icon
        guard let clickedIcon = icons.first(where: { $0.frame.contains(mousePointTopLeft) }) else {
            return Unmanaged.passRetained(event) // Not on dock, pass through
        }
        
        // Find the running app
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.localizedName == clickedIcon.title }) else {
            return Unmanaged.passRetained(event) // App not running, let Dock handle it
        }
        
        // If the clicked app was already the active app, toggle hide
        if app.bundleIdentifier == lastActiveAppBundleID && !app.isHidden {
            print("Intercepting click - hiding: \(clickedIcon.title)")
            app.hide()
            return nil // Block the click from reaching Dock
        } else if app.isHidden {
            print("App is hidden, letting Dock unhide: \(clickedIcon.title)")
            return Unmanaged.passRetained(event) // Let Dock handle unhide
        }
        
        return Unmanaged.passRetained(event) // Pass through for other cases
    }

    private func getDockAXUIElement() -> AXUIElement? {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        
        // Just check trusted, prompt handled in main
        if !AXIsProcessTrustedWithOptions(options) {
            // print("Accessibilty permissions needed")
        }

        let runningApps = NSWorkspace.shared.runningApplications
        guard let dockApp = runningApps.first(where: { $0.bundleIdentifier == dockBundleID }) else { return nil }
        return AXUIElementCreateApplication(dockApp.processIdentifier)
    }

    private func updateIcons() {
        guard let dockRef = getDockAXUIElement() else { return }

        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(dockRef, "AXChildren" as CFString, &children)
        
        guard result == .success, let childrenList = children as? [AXUIElement] else { return }
        
        var newIcons: [DockIcon] = []
        
        for child in childrenList {
            var role: AnyObject?
            AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &role)
            
            if let roleStr = role as? String, roleStr == "AXList" {
                 var listChildren: AnyObject?
                 AXUIElementCopyAttributeValue(child, "AXChildren" as CFString, &listChildren)
                 
                 if let iconList = listChildren as? [AXUIElement] {
                     for icon in iconList {
                        var title: AnyObject?
                        AXUIElementCopyAttributeValue(icon, "AXTitle" as CFString, &title)
                        
                        var frameValue: AnyObject?
                        AXUIElementCopyAttributeValue(icon, "AXFrame" as CFString, &frameValue)
                        
                        var rect = CGRect.zero
                        if let frameValue = frameValue, CFGetTypeID(frameValue) == AXValueGetTypeID() {
                             let axValue = frameValue as! AXValue
                             AXValueGetValue(axValue, .cgRect, &rect)
                        }
                        
                        // Ignore separators (usually empty title or very small width)
                        if let titleStr = title as? String, !titleStr.isEmpty, rect.width > 20 {
                            newIcons.append(DockIcon(title: titleStr, frame: rect, element: icon))
                        }
                     }
                 }
            }
        }
        
        DispatchQueue.main.async {
            self.icons = newIcons
        }
    }

    private func checkMousePosition() {
        let mouseLoc = NSEvent.mouseLocation
        // NSEvent.mouseLocation is in screen coordinates (origin bottom-left).
        
        guard let screenHeight = NSScreen.main?.frame.height else { return }
        // AXFrame (Quartz) is top-left origin.
        // But let's verify. The script output showed Y ~ 895 for dock icons on a screen.
        // If screen height is 900, 895 is near bottom. 
        // If origin was top-left, 895 would be bottom. 
        // If origin was bottom-left, 895 would be top (if screen height is > 1000).
        // Standard macOS screen coordinates (NSScreen) are bottom-left.
        // AX coordinates (Quartz) are top-left.
        
        // If the script said Frame Y is 895 and it's a bottom dock, on a 1080p screen?
        // Wait, 1080p = 1080 height. 895 is near bottom? No, 895 is near bottom only if origin is top-left.
        // If origin is bottom-left, 895 is near top.
        // Dock is usually at bottom.
        // So AX coordinates are Top-Left origin.
        
        // We need to convert mouseLoc (Bottom-Left) to Top-Left.
        let mousePointTopLeft = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)

        // Find hovered icon
        let found = icons.first { $0.frame.contains(mousePointTopLeft) }
        
        DispatchQueue.main.async {
            if self.hoveredIcon?.title != found?.title {
                self.hoveredIcon = found
                if let found = found {
                    print("Hovered: \(found.title)")
                } else {
                    // print("Hover ended")
                }
            }
        }
    }
}
