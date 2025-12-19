import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    
    /// Sends an image file to Cursor chat
    static func sendImage(imagePath: String) {
        let escapedPath = imagePath.replacingOccurrences(of: "\\", with: "\\\\")
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
            delay 0.2
            
            -- Copy image file to clipboard and paste
            set the clipboard to (read (POSIX file "\(escapedPath)") as JPEG picture)
            delay 0.3
            keystroke "v" using {command down}
            delay 0.2
        end tell
        """
        runAppleScript(script)
    }
    
    /// Sends an image with a message to Cursor chat
    static func sendImageWithMessage(imagePath: String, message: String) {
        let escapedPath = imagePath.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
            delay 0.2
            
            -- Copy and paste image
            set the clipboard to (read (POSIX file "\(escapedPath)") as JPEG picture)
            delay 0.3
            keystroke "v" using {command down}
            delay 0.2
            
            -- Type the message
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
        
        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 140
        
        // Calculate center position
        let x = screenFrame.midX - (windowWidth / 2)
        let y = screenFrame.midY - (windowHeight / 2)
        
        let window = NSPanel(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .fullSizeContentView, .closable],
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
        
        // Hide traffic lights (red, yellow, green buttons)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Activate app to allow typing
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Make sure the window can become key to receive keyboard input
        window.makeFirstResponder(window.contentView)
        
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
    @State private var imagePath: String? = nil
    @State private var isDragging: Bool = false
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
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Fechar")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Image preview (if image is attached)
            if let path = imagePath, let image = NSImage(contentsOfFile: path) {
                HStack(spacing: 8) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                    
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    // Remove image button
                    Button(action: { imagePath = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Remover imagem")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
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
                    .allowsHitTesting(true)
                    .onDrop(of: [.image, .fileURL], isTargeted: .constant(false)) { _ in
                        // Block drops on TextField, let parent handle it
                        return false
                    }
                
                // Image button
                Button(action: selectImage) {
                    Image(systemName: imagePath == nil ? "photo" : "photo.fill")
                        .font(.system(size: 14))
                        .foregroundColor(imagePath == nil ? .white.opacity(0.5) : cursorBlue)
                        .frame(width: 32, height: 32)
                        .background(imagePath == nil ? Color.white.opacity(0.05) : cursorBlue.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Selecionar imagem")
                
                // Send button
                Button(action: sendAndClose) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(canSend ? cursorBlue : .white.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .background(canSend ? cursorBlue.opacity(0.2) : Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Enviar")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 500)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                // Drag overlay
                if isDragging {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cursorBlue.opacity(0.1))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(cursorBlue)
                                Text("Solte a imagem aqui")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(cursorBlue)
                            }
                        )
                        .transition(.opacity)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDragging ? cursorBlue : cursorBlue.opacity(0.3), lineWidth: isDragging ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .onDrop(of: [.fileURL, .image], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            isFocused = true
            
            // Setup ESC key handler
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [onClose] event in
                if event.keyCode == 53 { // ESC key
                    onClose()
                    return nil
                }
                return event
            }
        }
    }
    
    private var canSend: Bool {
        !message.isEmpty || imagePath != nil
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Selecione uma imagem"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                imagePath = url.path
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // Try to load as file URL first
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                // Check if it's an image file
                let imageExtensions = ["png", "jpg", "jpeg", "heic", "gif", "bmp", "tiff"]
                let fileExtension = url.pathExtension.lowercased()
                
                if imageExtensions.contains(fileExtension) {
                    DispatchQueue.main.async {
                        self.imagePath = url.path
                    }
                }
            }
            return true
        }
        
        // Try to load as image data (for screenshots/clipboard)
        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                if let url = item as? URL {
                    // It's a file URL
                    DispatchQueue.main.async {
                        self.imagePath = url.path
                    }
                } else if let data = item as? Data, let image = NSImage(data: data) {
                    // It's raw image data - save to temp file
                    self.saveImageToTemp(image: image)
                } else if let image = item as? NSImage {
                    // Direct NSImage
                    self.saveImageToTemp(image: image)
                }
            }
            return true
        }
        
        return false
    }
    
    private func saveImageToTemp(image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        let tempDir = NSTemporaryDirectory()
        let fileName = "cursor_screenshot_\(UUID().uuidString).png"
        let tempPath = (tempDir as NSString).appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: URL(fileURLWithPath: tempPath))
            DispatchQueue.main.async {
                self.imagePath = tempPath
            }
        } catch {
            print("Error saving temp image: \(error)")
        }
    }
    
    private func sendAndClose() {
        guard canSend else { return }
        let msg = message
        let imgPath = imagePath
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let path = imgPath {
                if !msg.isEmpty {
                    CursorController.sendImageWithMessage(imagePath: path, message: msg)
                } else {
                    CursorController.sendImage(imagePath: path)
                }
            } else {
                CursorController.sendMessage(msg)
            }
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
