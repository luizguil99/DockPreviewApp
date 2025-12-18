import SwiftUI
import AppKit

// MARK: - Toggle Component

struct MenuToggleView: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(width: 320)
    }
}

// MARK: - Folder Item Model

struct FolderItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let icon: String
    
    var iconColor: Color {
        if isDirectory {
            return .blue
        }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return .red
        case "doc", "docx", "txt", "rtf", "md": return .blue
        case "xls", "xlsx", "csv": return .green
        case "ppt", "pptx": return .orange
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .purple
        case "mp3", "wav", "m4a", "aac": return .pink
        case "mp4", "mov", "avi", "mkv": return .indigo
        case "zip", "rar", "7z", "tar", "gz": return .gray
        case "swift", "js", "ts", "py", "html", "css", "json": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Folder Picker Manager

class FolderPickerManager: ObservableObject {
    static let shared = FolderPickerManager()
    
    @Published var selectedFolder: String? {
        didSet {
            if let path = selectedFolder {
                UserDefaults.standard.set(path, forKey: "selectedFolderPath")
                // Reset current browsing path when root folder changes
                currentBrowsePath = path
            }
        }
    }
    
    @Published var currentBrowsePath: String?
    
    init() {
        selectedFolder = UserDefaults.standard.string(forKey: "selectedFolderPath")
        currentBrowsePath = selectedFolder
    }
    
    var isAtRootFolder: Bool {
        guard let root = selectedFolder, let current = currentBrowsePath else {
            return true
        }
        return root == current
    }
    
    func navigateToFolder(_ path: String) {
        currentBrowsePath = path
    }
    
    func navigateBack() {
        guard let current = currentBrowsePath,
              let root = selectedFolder else { return }
        
        let parentPath = (current as NSString).deletingLastPathComponent
        
        // Don't go above the root folder
        if parentPath.hasPrefix(root) || parentPath == root {
            currentBrowsePath = parentPath
        } else {
            currentBrowsePath = root
        }
    }
    
    func navigateToRoot() {
        currentBrowsePath = selectedFolder
    }
    
    func createNewFolder(named name: String) -> Bool {
        guard let currentPath = currentBrowsePath else { return false }
        
        let newFolderPath = (currentPath as NSString).appendingPathComponent(name)
        
        do {
            try FileManager.default.createDirectory(atPath: newFolderPath, withIntermediateDirectories: false, attributes: nil)
            return true
        } catch {
            print("Error creating folder: \(error)")
            return false
        }
    }
    
    func showNewFolderDialog(completion: @escaping (Bool) -> Void) {
        guard currentBrowsePath != nil else { 
            completion(false)
            return 
        }
        
        // Activate the app temporarily to show the dialog
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter a name for the new folder:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "New Folder"
        textField.placeholderString = "Folder name"
        alert.accessoryView = textField
        
        // Make the text field first responder
        alert.window.initialFirstResponder = textField
        
        let response = alert.runModal()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
        
        if response == .alertFirstButtonReturn {
            let folderName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !folderName.isEmpty {
                let success = self.createNewFolder(named: folderName)
                completion(success)
                return
            }
        }
        
        completion(false)
    }
    
    func selectFolder() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder"
        panel.level = .floating
        
        if let currentPath = selectedFolder {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }
        
        let response = panel.runModal()
        
        if response == .OK, let url = panel.url {
            self.selectedFolder = url.path
            print("Selected folder: \(url.path)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func openInCursor(path: String? = nil) {
        openWithApp(path: path, appName: "Cursor", cliCommand: "cursor")
    }
    
    func openInVSCode(path: String? = nil) {
        openWithApp(path: path, appName: "Visual Studio Code", cliCommand: "code")
    }
    
    func openInZed(path: String? = nil) {
        openWithApp(path: path, appName: "Zed", cliCommand: "zed")
    }
    
    func openInWarp(path: String? = nil) {
        let targetPath = path ?? selectedFolder
        guard let folderPath = targetPath else { return }
        
        // Warp needs special handling - open terminal at directory
        let warpPaths = [
            "/Applications/Warp.app",
            NSHomeDirectory() + "/Applications/Warp.app"
        ]
        
        for warpPath in warpPaths {
            if FileManager.default.fileExists(atPath: warpPath) {
                let warpURL = URL(fileURLWithPath: warpPath)
                let configuration = NSWorkspace.OpenConfiguration()
                
                // Create a script to cd to directory
                let script = """
                tell application "Warp"
                    activate
                    tell application "System Events"
                        keystroke "cd \(folderPath)" & return
                    end tell
                end tell
                """
                
                NSWorkspace.shared.open(warpURL)
                
                // Run AppleScript after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.runAppleScript(script)
                }
                return
            }
        }
        
        // Fallback: try CLI
        openWithCLI(cliCommand: "warp", path: folderPath)
    }
    
    private func openWithApp(path: String?, appName: String, cliCommand: String) {
        let targetPath = path ?? selectedFolder
        guard let folderPath = targetPath else { return }
        
        let appPaths = [
            "/Applications/\(appName).app",
            NSHomeDirectory() + "/Applications/\(appName).app"
        ]
        
        var appURL: URL?
        for appPath in appPaths {
            if FileManager.default.fileExists(atPath: appPath) {
                appURL = URL(fileURLWithPath: appPath)
                break
            }
        }
        
        if let appURL = appURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [folderPath]
            
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: folderPath)],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                if let error = error {
                    print("Error opening with \(appName): \(error)")
                    self.openWithCLI(cliCommand: cliCommand, path: folderPath)
                }
            }
        } else {
            openWithCLI(cliCommand: cliCommand, path: folderPath)
        }
    }
    
    private func openWithCLI(cliCommand: String, path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [cliCommand, path]
        
        do {
            try task.run()
        } catch {
            print("Error opening with \(cliCommand) CLI: \(error)")
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }
    
    private func runAppleScript(_ script: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}

// MARK: - App Button Component

struct AppButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isHovered ? color.opacity(0.25) : color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Folder Browser View

struct MenuFolderBrowserView: View {
    @ObservedObject var manager = FolderPickerManager.shared
    @State private var items: [FolderItem] = []
    @State private var allItems: [FolderItem] = []
    @State private var searchText: String = ""
    @State private var isHoveringHeader = false
    @State private var isHoveringBack = false
    @State private var isHoveringNewFolder = false
    @State private var isHoveringHome = false
    
    var currentFolderName: String {
        if let path = manager.currentBrowsePath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "Select Folder"
    }
    
    var filteredItems: [FolderItem] {
        if searchText.isEmpty {
            return allItems
        }
        return allItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation header
            HStack(spacing: 8) {
                // Back button (only show when not at root)
                if !manager.isAtRootFolder {
                    Button(action: { 
                        manager.navigateBack()
                        loadFolderContents()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isHoveringBack ? .primary : .secondary)
                            .frame(width: 28, height: 28)
                            .background(isHoveringBack ? Color.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringBack = hovering
                    }
                    .help("Back")
                    
                    // Home button to go directly to root
                    Button(action: { 
                        manager.navigateToRoot()
                        loadFolderContents()
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isHoveringHome ? .primary : .secondary)
                            .frame(width: 28, height: 28)
                            .background(isHoveringHome ? Color.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringHome = hovering
                    }
                    .help("Go to root folder")
                }
                
                // Folder name button
                Button(action: { manager.selectFolder() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text(currentFolderName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isHoveringHeader ? Color.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringHeader = hovering
                }
                .help("Change root folder")
                
                Spacer()
                
                // New folder button
                if manager.selectedFolder != nil {
                    Button(action: { 
                        manager.showNewFolderDialog { success in
                            if success {
                                loadFolderContents()
                            }
                        }
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(isHoveringNewFolder ? .blue : .secondary)
                            .frame(width: 32, height: 28)
                            .background(isHoveringNewFolder ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringNewFolder = hovering
                    }
                    .help("Create new folder")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // App buttons row (dynamic from CustomAppManager)
            if manager.selectedFolder != nil, let currentPath = manager.currentBrowsePath {
                ScrollView(.horizontal, showsIndicators: false) {
                    DynamicAppButtonsRow(path: currentPath)
                        .padding(.horizontal, 14)
                }
                .padding(.vertical, 8)
            }
            
            Divider()
                .padding(.horizontal, 10)
            
            // Search field
            if manager.selectedFolder != nil {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // Folder contents
            if manager.selectedFolder != nil {
                if filteredItems.isEmpty {
                    Text(searchText.isEmpty ? "Empty folder" : "No results for \"\(searchText)\"")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredItems) { item in
                                FolderItemRow(item: item, onFolderTap: { path in
                                    manager.navigateToFolder(path)
                                    searchText = ""
                                    loadFolderContents()
                                })
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("Click to select a folder")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 320)
        .onAppear {
            if manager.currentBrowsePath == nil {
                manager.currentBrowsePath = manager.selectedFolder
            }
            loadFolderContents()
        }
        .onReceive(manager.$selectedFolder) { _ in
            loadFolderContents()
        }
        .onReceive(manager.$currentBrowsePath) { _ in
            loadFolderContents()
        }
    }
    
    private func loadFolderContents() {
        guard let path = manager.currentBrowsePath ?? manager.selectedFolder else {
            allItems = []
            return
        }
        
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            allItems = contents.compactMap { itemURL in
                let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let icon = isDir ? "folder.fill" : fileIcon(for: itemURL.pathExtension)
                
                return FolderItem(
                    name: itemURL.lastPathComponent,
                    path: itemURL.path,
                    isDirectory: isDir,
                    icon: icon
                )
            }.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        } catch {
            print("Error loading folder contents: \(error)")
            allItems = []
        }
    }
    
    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.fill"
        case "doc", "docx", "txt", "rtf": return "doc.text.fill"
        case "md": return "text.document"
        case "xls", "xlsx", "csv": return "tablecells.fill"
        case "ppt", "pptx": return "play.rectangle.fill"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo.fill"
        case "mp3", "wav", "m4a", "aac": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "swift": return "swift"
        case "js", "ts": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "html", "css": return "globe"
        case "json": return "curlybraces.square"
        default: return "doc.fill"
        }
    }
}

// MARK: - Folder Item Row

struct FolderItemRow: View {
    let item: FolderItem
    var onFolderTap: ((String) -> Void)?
    @State private var isHovered = false
    @State private var showButtons = false
    @State private var hoverTask: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 0) {
            // Main clickable area
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .foregroundColor(item.iconColor)
                    .font(.system(size: 18))
                    .frame(width: 24)

                Text(item.name)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Show chevron for folders to indicate navigation
                if item.isDirectory && !showButtons {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle()) // Ensures entire area is clickable
            .onTapGesture {
                handleTap()
            }

            // Show app buttons for folders on hover (with delay to prevent click interference)
            if item.isDirectory && showButtons {
                DynamicMiniAppButtons(path: item.path, includeFinder: true)
                    .padding(.trailing, 12)
            }
        }
        .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
            
            // Cancel any pending task
            hoverTask?.cancel()
            
            if hovering && item.isDirectory {
                // Show buttons after a short delay to prevent interference with clicks
                let task = DispatchWorkItem { [self] in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showButtons = true
                    }
                }
                hoverTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
            } else {
                // Hide buttons immediately when not hovering
                withAnimation(.easeInOut(duration: 0.1)) {
                    showButtons = false
                }
            }
        }
    }
    
    private func handleTap() {
        if item.isDirectory {
            // Navigate into the folder
            onFolderTap?(item.path)
        } else {
            // Open files normally
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }
}

// MARK: - Mini App Button

struct MiniAppButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 24, height: 24)
                .background(isHovered ? color.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
