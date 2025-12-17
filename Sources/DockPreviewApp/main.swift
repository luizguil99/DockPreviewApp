import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayManager: OverlayWindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("Please grant Accessibility permissions in System Settings.")
        }
        
        // Hide dock icon for this background app
        NSApp.setActivationPolicy(.accessory)
        
        overlayManager = OverlayWindowManager()
        print("DockPreviewApp started.")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

