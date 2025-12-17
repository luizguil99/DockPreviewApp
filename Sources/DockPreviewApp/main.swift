import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayManager: OverlayWindowManager?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("Please grant Accessibility permissions in System Settings.")
        }
        
        // Setup menu bar FIRST
        setupMenuBar()
        
        // Hide dock icon for this background app
        NSApp.setActivationPolicy(.accessory)
        
        overlayManager = OverlayWindowManager()
        print("DockPreviewApp started.")
    }
    
    func setupMenuBar() {
        print("Setting up menu bar...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("Status item created: \(statusItem != nil)")
        
        if let button = statusItem?.button {
            button.title = "DP"
            button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            print("Button title set to 'DP'")
        } else {
            print("ERROR: No button!")
        }
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Click to Hide", action: #selector(toggleClickToHide), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        print("Menu bar setup complete")
    }
    
    @objc func toggleClickToHide(_ sender: NSMenuItem) {
        DockMonitor.shared.clickToHideEnabled.toggle()
        sender.state = DockMonitor.shared.clickToHideEnabled ? .on : .off
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

