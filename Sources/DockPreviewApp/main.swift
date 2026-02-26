import Cocoa
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayManager: OverlayWindowManager?
    var statusItem: NSStatusItem?
    var globalHotkeyMonitor: Any?
    var localHotkeyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar FIRST (always works)
        setupMenuBar()
        
        // Setup global hotkey (⌥Space to open menu)
        setupGlobalHotkey()
        
        // Hide dock icon for this background app
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions - only prompt once
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            print("Accessibility permissions needed. Showing prompt...")
            // Show prompt only once
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        
        overlayManager = OverlayWindowManager()
        print("DockPreviewApp started. Accessibility trusted: \(trusted)")
    }
    
    func setupGlobalHotkey() {
        // Global monitor for when app is not focused (⌥Space)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        
        // Local monitor for when app is focused
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event) == true {
                return nil // Consume the event
            }
            return event
        }
        
        print("Global hotkeys setup:")
        print("  ⌃⌥D - Open menu")
        print("  ⌃⌥L - Toggle Cursor chat input")
    }
    
    @discardableResult
    private func handleHotkey(_ event: NSEvent) -> Bool {
        // Check for modifier keys
        let controlPressed = event.modifierFlags.contains(.control)
        let optionPressed = event.modifierFlags.contains(.option)
        let isDKey = event.keyCode == 2 // D key
        let isLKey = event.keyCode == 37 // L key
        
        // ⌃⌥D - Open menu bar menu
        if controlPressed && optionPressed && isDKey {
            DispatchQueue.main.async {
                self.openMenuBarMenu()
            }
            return true
        }
        
        // ⌃⌥L - Toggle Cursor Chat Input
        if controlPressed && optionPressed && isLKey {
            DispatchQueue.main.async {
                self.toggleCursorChatInput()
            }
            return true
        }
        
        return false
    }
    
    func openMenuBarMenu() {
        guard let button = statusItem?.button else {
            print("No status item button found")
            return
        }
        
        // Simulate a click on the status item to open the menu
        if let menu = statusItem?.menu {
            // Position the menu below the status item button
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            menu.popUp(positioning: nil, at: NSPoint(x: buttonFrame.origin.x, y: buttonFrame.origin.y), in: nil)
        }
    }
    
    func toggleCursorChatInput() {
        // Check if window is already open
        if let window = CursorController.chatWindow, window.isVisible {
            // Close the window
            window.close()
            CursorController.chatWindow = nil
        } else {
            // Open the window
            CursorController.openChatInput()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup hotkey monitors
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        
        // Folder browser (from MenuComponents.swift)
        let folderBrowserView = MenuFolderBrowserView()
        let folderHostingView = NSHostingView(rootView: folderBrowserView)
        folderHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 450)
        
        let folderItem = NSMenuItem()
        folderItem.view = folderHostingView
        menu.addItem(folderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Click to Hide toggle
        let toggleView = DockMonitorToggleView(
            title: "Click to Hide",
            keyPath: \.clickToHideEnabled
        )
        let hostingView = NSHostingView(rootView: toggleView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)
        
        let toggleItem = NSMenuItem()
        toggleItem.view = hostingView
        menu.addItem(toggleItem)
        
        // Chrome Profiles toggle
        let chromeToggleView = DockMonitorToggleView(
            title: "Chrome Profiles",
            keyPath: \.chromeProfilesEnabled
        )
        let chromeHostingView = NSHostingView(rootView: chromeToggleView)
        chromeHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)
        
        let chromeToggleItem = NSMenuItem()
        chromeToggleItem.view = chromeHostingView
        menu.addItem(chromeToggleItem)
        
        // Cursor Overlay toggle
        let cursorToggleView = DockMonitorToggleView(
            title: "Cursor Overlay",
            keyPath: \.cursorOverlayEnabled
        )
        let cursorHostingView = NSHostingView(rootView: cursorToggleView)
        cursorHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)
        
        let cursorToggleItem = NSMenuItem()
        cursorToggleItem.view = cursorHostingView
        menu.addItem(cursorToggleItem)
        
        // Compact Overlay Mode toggle
        let compactToggleView = DockMonitorToggleView(
            title: "Compact Overlay",
            keyPath: \.compactOverlayMode
        )
        let compactHostingView = NSHostingView(rootView: compactToggleView)
        compactHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)
        
        let compactToggleItem = NSMenuItem()
        compactToggleItem.view = compactHostingView
        menu.addItem(compactToggleItem)
        
        // Show Kill Button toggle
        let killButtonToggleView = DockMonitorToggleView(
            title: "Show Kill Button",
            keyPath: \.showKillButton
        )
        let killButtonHostingView = NSHostingView(rootView: killButtonToggleView)
        killButtonHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)

        let killButtonToggleItem = NSMenuItem()
        killButtonToggleItem.view = killButtonHostingView
        menu.addItem(killButtonToggleItem)

        // Activate on hover toggle
        let hoverToggleView = DockMonitorToggleView(
            title: "Activate Window on Hover",
            keyPath: \.activateOnHover
        )
        let hoverHostingView = NSHostingView(rootView: hoverToggleView)
        hoverHostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 32)

        let hoverToggleItem = NSMenuItem()
        hoverToggleItem.view = hoverHostingView
        menu.addItem(hoverToggleItem)

        menu.addItem(NSMenuItem.separator())
        
        // Ask Cursor AI
        let askCursorItem = NSMenuItem(title: "Ask Cursor AI", action: #selector(toggleCursorChat), keyEquivalent: "l")
        askCursorItem.keyEquivalentModifierMask = [.control, .option]
        askCursorItem.target = self
        if let icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Ask Cursor AI") {
            icon.isTemplate = true
            askCursorItem.image = icon
        }
        menu.addItem(askCursorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open With Settings
        let openWithItem = NSMenuItem(title: "Configure Open With...", action: #selector(openAppSettings), keyEquivalent: ",")
        openWithItem.target = self
        if let icon = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Open With Settings") {
            icon.isTemplate = true
            openWithItem.image = icon
        }
        menu.addItem(openWithItem)
        
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
    
    var settingsWindow: NSWindow?
    
    @objc func toggleCursorChat() {
        toggleCursorChatInput()
    }
    
    @objc func openAppSettings() {
        // If window already exists, just bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let settingsView = CustomAppSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Open With Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 320, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        
        // Handle window close to return to accessory mode
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.setActivationPolicy(.accessory)
                self?.settingsWindow = nil
            }
        }
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
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
