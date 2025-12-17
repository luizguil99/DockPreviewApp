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

    init() {
        startMonitoring()
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
