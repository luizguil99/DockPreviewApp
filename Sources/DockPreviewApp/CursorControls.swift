import SwiftUI
import AppKit

// MARK: - Cursor Controller
class CursorController {
    
    static var chatWindow: NSWindow?
    
    static func isCursor(_ appName: String) -> Bool {
        return appName.lowercased() == "cursor"
    }
    
    /// Opens a new chat in Cursor (Cmd+Shift+L)
    static func openNewChat() {
        let script = """
        tell application "Cursor"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            keystroke "l" using {command down, shift down}
            delay 0.3
            keystroke "a" using {command down}
            key code 51
        end tell
        """
        runAppleScript(script)
    }
    
    /// Opens a new window in Cursor (Cmd+Shift+N)
    static func openNewWindow() {
        let script = """
        tell application "Cursor"
            activate
        end tell
        delay 0.2
        tell application "System Events"
            keystroke "n" using {command down, shift down}
        end tell
        """
        runAppleScript(script)
    }
    
    /// Sends a message to Cursor chat
    static func sendMessage(_ message: String) {
        let escapedMessage = message.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Cursor"
            activate
        end tell
        delay 0.5
        tell application "System Events"
            keystroke "l" using {command down}
            delay 0.3
            keystroke "a" using {command down}
            key code 51
            delay 0.1
            keystroke "\(escapedMessage)"
            delay 0.1
            key code 36
        end tell
        """
        runAppleScript(script)
    }
    
    /// Opens the floating chat input window
    static func openChatInput() {
        // Close existing window if any
        chatWindow?.close()
        
        let contentView = CursorChatInputView {
            chatWindow?.close()
            chatWindow = nil
        }
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentViewController = hostingController
        window.center()
        
        // Activate app to allow typing
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        chatWindow = window
    }
    
    private static func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                }
            }
        }
    }
}

// MARK: - Floating Chat Input View
struct CursorChatInputView: View {
    @State private var message: String = ""
    @FocusState private var isFocused: Bool
    var onClose: () -> Void
    
    let cursorBlue = Color(red: 0.4, green: 0.6, blue: 1.0)
    
    // Get Cursor app icon
    private var cursorIcon: NSImage? {
        let appPaths = [
            "/Applications/Cursor.app",
            NSHomeDirectory() + "/Applications/Cursor.app"
        ]
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                if let icon = cursorIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                
                Text("Send to Cursor")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .onHover { h in }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Input field
            HStack(spacing: 10) {
                TextField("Ask Cursor AI anything...", text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .onSubmit {
                        sendAndClose()
                    }
                
                // Send button
                Button(action: sendAndClose) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(message.isEmpty ? .white.opacity(0.3) : cursorBlue)
                        .frame(width: 32, height: 32)
                        .background(message.isEmpty ? Color.white.opacity(0.1) : cursorBlue.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(message.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cursorBlue.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
    
    private func sendAndClose() {
        guard !message.isEmpty else { return }
        let msg = message
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CursorController.sendMessage(msg)
        }
    }
}

// MARK: - Cursor Quick Actions Card
struct CursorQuickActionsCard: View {
    @State private var hoveredButton: String? = nil
    @State private var isHovered = false
    
    let cursorBlue = Color(red: 0.4, green: 0.6, blue: 1.0)
    
    // Get Cursor app icon
    private var cursorIcon: NSImage? {
        let appPaths = [
            "/Applications/Cursor.app",
            NSHomeDirectory() + "/Applications/Cursor.app"
        ]
        for path in appPaths {
            if let bundle = Bundle(path: path),
               let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String ?? bundle.infoDictionary?["CFBundleIconName"] as? String {
                let iconPath = bundle.resourcePath ?? ""
                let fullPath = iconName.hasSuffix(".icns") ? "\(iconPath)/\(iconName)" : "\(iconPath)/\(iconName).icns"
                if let icon = NSImage(contentsOfFile: fullPath) {
                    return icon
                }
            }
            // Fallback: use NSWorkspace
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with app icon
            HStack(spacing: 5) {
                if let icon = cursorIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(cursorBlue)
                }
                Text("Cursor")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Action buttons
            HStack(spacing: 8) {
                // Ask AI button (opens floating input)
                actionButton(
                    icon: "sparkles",
                    label: "Ask",
                    id: "ask"
                ) {
                    CursorController.openChatInput()
                }
                
                // New Chat button
                actionButton(
                    icon: "plus.message.fill",
                    label: "Chat",
                    id: "chat"
                ) {
                    CursorController.openNewChat()
                }
                
                // New Window button
                actionButton(
                    icon: "macwindow.badge.plus",
                    label: "Window",
                    id: "window"
                ) {
                    CursorController.openNewWindow()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? cursorBlue.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { h in isHovered = h }
    }
    
    private func actionButton(icon: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hoveredButton == id ? cursorBlue.opacity(0.3) : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(hoveredButton == id ? cursorBlue : .white.opacity(0.7))
                }
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(hoveredButton == id ? cursorBlue : .white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(hoveredButton == id ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: hoveredButton)
        .onHover { h in hoveredButton = h ? id : nil }
    }
}
