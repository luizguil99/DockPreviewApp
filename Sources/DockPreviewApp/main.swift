import Cocoa
import SwiftUI

// Custom view for toggle switch in menu
struct MenuToggleView: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(width: 200)
    }
}

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
            // Use SF Symbol for macOS 11+
            if let image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "DockPreview") {
                image.isTemplate = true
                button.image = image
                print("Button icon set")
            } else {
                button.title = "DP"
                print("Fallback to text 'DP'")
            }
        } else {
            print("ERROR: No button!")
        }
        
        let menu = NSMenu()
        
        // Click to Hide toggle with slider
        let toggleView = MenuToggleView(
            title: "Click to Hide",
            isOn: Binding(
                get: { DockMonitor.shared.clickToHideEnabled },
                set: { DockMonitor.shared.clickToHideEnabled = $0 }
            )
        )
        let hostingView = NSHostingView(rootView: toggleView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 28)
        
        let toggleItem = NSMenuItem()
        toggleItem.view = hostingView
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Permissions section header
        let permissionsHeader = NSMenuItem(title: "Permissions", action: nil, keyEquivalent: "")
        permissionsHeader.isEnabled = false
        menu.addItem(permissionsHeader)
        
        // Accessibility permission
        let accessibilityItem = NSMenuItem(title: "   Accessibility...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        if let icon = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Accessibility") {
            icon.isTemplate = true
            accessibilityItem.image = icon
        }
        menu.addItem(accessibilityItem)
        
        // Screen Recording permission
        let screenRecordingItem = NSMenuItem(title: "   Screen Recording...", action: #selector(openScreenRecordingSettings), keyEquivalent: "")
        screenRecordingItem.target = self
        if let icon = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Recording") {
            icon.isTemplate = true
            screenRecordingItem.image = icon
        }
        menu.addItem(screenRecordingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        print("Menu bar setup complete")
    }
    
    @objc func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

