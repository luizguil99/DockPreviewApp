import SwiftUI
import AppKit

// MARK: - Toggle Component

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
        .frame(width: 280)
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
            }
        }
    }
    
    init() {
        selectedFolder = UserDefaults.standard.string(forKey: "selectedFolderPath")
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
    
    var folderName: String {
        if let path = manager.selectedFolder {
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
            // Header with folder name
            Button(action: { manager.selectFolder() }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text(folderName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isHoveringHeader ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringHeader = hovering
            }
            
            // App buttons row
            if manager.selectedFolder != nil {
                HStack(spacing: 6) {
                    AppButton(icon: "cursorarrow.rays", label: "Cursor", color: .blue) {
                        manager.openInCursor()
                    }
                    AppButton(icon: "chevron.left.forwardslash.chevron.right", label: "VSCode", color: .cyan) {
                        manager.openInVSCode()
                    }
                    AppButton(icon: "text.cursor", label: "Zed", color: .orange) {
                        manager.openInZed()
                    }
                    AppButton(icon: "terminal", label: "Warp", color: .pink) {
                        manager.openInWarp()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            // Search field
            if manager.selectedFolder != nil {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            
            // Folder contents
            if manager.selectedFolder != nil {
                if filteredItems.isEmpty {
                    Text(searchText.isEmpty ? "Empty folder" : "No results for \"\(searchText)\"")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredItems) { item in
                                FolderItemRow(item: item)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 250)
                }
            } else {
                Text("Click to select a folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 280)
        .onAppear {
            loadFolderContents()
        }
        .onReceive(manager.$selectedFolder) { _ in
            loadFolderContents()
        }
    }
    
    private func loadFolderContents() {
        guard let path = manager.selectedFolder else {
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
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
            }) {
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .foregroundColor(item.iconColor)
                        .font(.system(size: 14))
                        .frame(width: 18)
                    
                    Text(item.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // Show app buttons for folders on hover
            if item.isDirectory && isHovered {
                HStack(spacing: 4) {
                    MiniAppButton(icon: "cursorarrow.rays", color: .blue) {
                        FolderPickerManager.shared.openInCursor(path: item.path)
                    }
                    MiniAppButton(icon: "chevron.left.forwardslash.chevron.right", color: .cyan) {
                        FolderPickerManager.shared.openInVSCode(path: item.path)
                    }
                    MiniAppButton(icon: "text.cursor", color: .orange) {
                        FolderPickerManager.shared.openInZed(path: item.path)
                    }
                    MiniAppButton(icon: "terminal", color: .pink) {
                        FolderPickerManager.shared.openInWarp(path: item.path)
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
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
                .font(.system(size: 9))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
