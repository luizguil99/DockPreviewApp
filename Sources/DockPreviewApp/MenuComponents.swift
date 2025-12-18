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
        let targetPath = path ?? selectedFolder
        guard let folderPath = targetPath else { return }
        
        // Try to open with Cursor
        let cursorURLs = [
            "/Applications/Cursor.app",
            NSHomeDirectory() + "/Applications/Cursor.app"
        ]
        
        var cursorURL: URL?
        for path in cursorURLs {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                cursorURL = url
                break
            }
        }
        
        if let cursorURL = cursorURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [folderPath]
            
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: folderPath)],
                withApplicationAt: cursorURL,
                configuration: configuration
            ) { _, error in
                if let error = error {
                    print("Error opening with Cursor: \(error)")
                    // Fallback: try using open command
                    self.openWithCursorCLI(path: folderPath)
                }
            }
        } else {
            // Try CLI
            openWithCursorCLI(path: folderPath)
        }
    }
    
    private func openWithCursorCLI(path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["cursor", path]
        
        do {
            try task.run()
        } catch {
            print("Error opening with cursor CLI: \(error)")
            // Last resort: open in Finder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }
}

// MARK: - Folder Browser View

struct MenuFolderBrowserView: View {
    @ObservedObject var manager = FolderPickerManager.shared
    @State private var items: [FolderItem] = []
    @State private var isHoveringHeader = false
    @State private var isHoveringCursor = false
    
    var folderName: String {
        if let path = manager.selectedFolder {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "Select Folder"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with folder name
            HStack(spacing: 0) {
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
                
                Spacer()
                
                // Open in Cursor button
                if manager.selectedFolder != nil {
                    Button(action: { manager.openInCursor() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "cursorarrow.rays")
                                .font(.system(size: 11))
                            Text("Cursor")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isHoveringCursor ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringCursor = hovering
                    }
                    .padding(.trailing, 8)
                }
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            // Folder contents
            if manager.selectedFolder != nil {
                if items.isEmpty {
                    Text("Empty folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(items) { item in
                                FolderItemRow(item: item)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 300)
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
            items = []
            return
        }
        
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            items = contents.compactMap { itemURL in
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
            items = []
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
    @State private var isHoveringCursor = false
    
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
            
            // Show Cursor button for folders on hover
            if item.isDirectory && isHovered {
                Button(action: {
                    FolderPickerManager.shared.openInCursor(path: item.path)
                }) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 10))
                        .foregroundColor(isHoveringCursor ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringCursor = hovering
                }
                .padding(.trailing, 12)
            }
        }
        .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
