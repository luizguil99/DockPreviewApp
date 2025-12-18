import SwiftUI
import AppKit

// MARK: - Custom App Model

struct CustomApp: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var color: String // Color name
    var appPath: String? // Path to .app bundle
    var cliCommand: String? // CLI command to run
    var isEnabled: Bool
    var usesAppleScript: Bool // For apps that need special handling
    var appleScript: String? // Custom AppleScript
    
    init(id: UUID = UUID(), name: String, icon: String, color: String, appPath: String? = nil, cliCommand: String? = nil, isEnabled: Bool = true, usesAppleScript: Bool = false, appleScript: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.appPath = appPath
        self.cliCommand = cliCommand
        self.isEnabled = isEnabled
        self.usesAppleScript = usesAppleScript
        self.appleScript = appleScript
    }
    
    var swiftUIColor: Color {
        switch color.lowercased() {
        case "blue": return .blue
        case "cyan": return .cyan
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "indigo": return .indigo
        case "mint": return .mint
        case "teal": return .teal
        case "brown": return .brown
        default: return .blue
        }
    }
}

// MARK: - Preset Apps

struct PresetApps {
    static let terminal = CustomApp(
        name: "Terminal",
        icon: "terminal",
        color: "gray",
        appPath: "/System/Applications/Utilities/Terminal.app",
        cliCommand: nil,
        usesAppleScript: true,
        appleScript: """
        tell application "Terminal"
            activate
            do script "cd \\"{path}\\""
        end tell
        """
    )
    
    static let iterm = CustomApp(
        name: "iTerm",
        icon: "terminal.fill",
        color: "green",
        appPath: "/Applications/iTerm.app",
        usesAppleScript: true,
        appleScript: """
        tell application "iTerm"
            activate
            tell current window
                create tab with default profile
                tell current session
                    write text "cd \\"{path}\\""
                end tell
            end tell
        end tell
        """
    )
    
    static let cursor = CustomApp(
        name: "Cursor",
        icon: "cursorarrow.rays",
        color: "blue",
        appPath: "/Applications/Cursor.app",
        cliCommand: "cursor"
    )
    
    static let vscode = CustomApp(
        name: "VSCode",
        icon: "chevron.left.forwardslash.chevron.right",
        color: "cyan",
        appPath: "/Applications/Visual Studio Code.app",
        cliCommand: "code"
    )
    
    static let zed = CustomApp(
        name: "Zed",
        icon: "text.cursor",
        color: "orange",
        appPath: "/Applications/Zed.app",
        cliCommand: "zed"
    )
    
    static let warp = CustomApp(
        name: "Warp",
        icon: "terminal",
        color: "pink",
        appPath: "/Applications/Warp.app",
        usesAppleScript: true,
        appleScript: """
        tell application "Warp"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            keystroke "cd \\"{path}\\"" & return
        end tell
        """
    )
    
    static let finder = CustomApp(
        name: "Finder",
        icon: "folder",
        color: "blue",
        appPath: "/System/Library/CoreServices/Finder.app"
    )
    
    static let sublime = CustomApp(
        name: "Sublime",
        icon: "doc.text",
        color: "orange",
        appPath: "/Applications/Sublime Text.app",
        cliCommand: "subl"
    )
    
    static let nova = CustomApp(
        name: "Nova",
        icon: "sparkle",
        color: "purple",
        appPath: "/Applications/Nova.app"
    )
    
    static let xcode = CustomApp(
        name: "Xcode",
        icon: "hammer",
        color: "blue",
        appPath: "/Applications/Xcode.app"
    )
    
    static let allPresets: [CustomApp] = [
        cursor, vscode, zed, warp, terminal, iterm, finder, sublime, nova, xcode
    ]
    
    static let defaultEnabled: [CustomApp] = [
        cursor, vscode, zed, warp
    ]
}

// MARK: - Custom App Manager

class CustomAppManager: ObservableObject {
    static let shared = CustomAppManager()
    
    @Published var apps: [CustomApp] = []
    
    private let userDefaultsKey = "customApps"
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CustomApp].self, from: data) {
            apps = decoded
        } else {
            // First launch - use default apps
            apps = PresetApps.defaultEnabled
            saveApps()
        }
    }
    
    func saveApps() {
        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func addApp(_ app: CustomApp) {
        apps.append(app)
        saveApps()
    }
    
    func removeApp(at index: Int) {
        guard index >= 0 && index < apps.count else { return }
        apps.remove(at: index)
        saveApps()
    }
    
    func removeApp(id: UUID) {
        apps.removeAll { $0.id == id }
        saveApps()
    }
    
    func updateApp(_ app: CustomApp) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = app
            saveApps()
        }
    }
    
    func moveApp(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        saveApps()
    }
    
    func toggleApp(id: UUID) {
        if let index = apps.firstIndex(where: { $0.id == id }) {
            apps[index].isEnabled.toggle()
            saveApps()
        }
    }
    
    var enabledApps: [CustomApp] {
        apps.filter { $0.isEnabled }
    }
    
    // MARK: - Open With App
    
    func openWithApp(_ app: CustomApp, path: String) {
        if app.name == "Finder" {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
            return
        }
        
        if app.usesAppleScript, let script = app.appleScript {
            let finalScript = script.replacingOccurrences(of: "{path}", with: path)
            runAppleScript(finalScript)
            return
        }
        
        // Try to open with app bundle first
        if let appPath = app.appPath {
            let possiblePaths = [
                appPath,
                NSHomeDirectory() + "/Applications/" + URL(fileURLWithPath: appPath).lastPathComponent
            ]
            
            for possiblePath in possiblePaths {
                if FileManager.default.fileExists(atPath: possiblePath) {
                    let appURL = URL(fileURLWithPath: possiblePath)
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.arguments = [path]
                    
                    NSWorkspace.shared.open(
                        [URL(fileURLWithPath: path)],
                        withApplicationAt: appURL,
                        configuration: configuration
                    ) { _, error in
                        if let error = error {
                            print("Error opening with \(app.name): \(error)")
                            // Fallback to CLI if available
                            if let cli = app.cliCommand {
                                self.openWithCLI(cli, path: path)
                            }
                        }
                    }
                    return
                }
            }
        }
        
        // Fallback to CLI
        if let cli = app.cliCommand {
            openWithCLI(cli, path: path)
        }
    }
    
    private func openWithCLI(_ command: String, path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [command, path]
        
        do {
            try task.run()
        } catch {
            print("Error opening with \(command) CLI: \(error)")
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

// MARK: - Custom App Settings View

struct CustomAppSettingsView: View {
    @ObservedObject var manager = CustomAppManager.shared
    @State private var showAddPreset = false
    @State private var showAddCustom = false
    @State private var editingApp: CustomApp? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Open With Apps")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Menu {
                    Button("Add from presets...") {
                        showAddPreset = true
                    }
                    Button("Add custom app...") {
                        showAddCustom = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Apps list
            if manager.apps.isEmpty {
                Text("No apps configured")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(manager.apps) { app in
                            CustomAppRow(app: app, onEdit: {
                                editingApp = app
                            }, onDelete: {
                                manager.removeApp(id: app.id)
                            }, onToggle: {
                                manager.toggleApp(id: app.id)
                            })
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 200)
            }
            
            // Info text
            Text("Drag to reorder • Click toggle to enable/disable")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 280)
        .sheet(isPresented: $showAddPreset) {
            PresetAppPickerView(manager: manager)
        }
        .sheet(isPresented: $showAddCustom) {
            CustomAppEditorView(manager: manager, app: nil)
        }
        .sheet(item: $editingApp) { app in
            CustomAppEditorView(manager: manager, app: app)
        }
    }
}

// MARK: - Custom App Row

struct CustomAppRow: View {
    let app: CustomApp
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Image(systemName: app.icon)
                .font(.system(size: 12))
                .foregroundColor(app.isEnabled ? app.swiftUIColor : .gray)
                .frame(width: 20)
            
            // App name
            Text(app.name)
                .font(.system(size: 12))
                .foregroundColor(app.isEnabled ? .primary : .secondary)
            
            Spacer()
            
            if isHovered {
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { app.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.6)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preset App Picker View

struct PresetAppPickerView: View {
    @ObservedObject var manager: CustomAppManager
    @Environment(\.dismiss) var dismiss
    
    var availablePresets: [CustomApp] {
        PresetApps.allPresets.filter { preset in
            !manager.apps.contains { $0.name == preset.name }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Add Preset App")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding()
            
            Divider()
            
            if availablePresets.isEmpty {
                Text("All preset apps have been added")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(availablePresets) { preset in
                            PresetAppRow(app: preset) {
                                var newApp = preset
                                newApp.id = UUID()
                                manager.addApp(newApp)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 300, height: 350)
    }
}

// MARK: - Preset App Row

struct PresetAppRow: View {
    let app: CustomApp
    let onAdd: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: app.icon)
                .font(.system(size: 14))
                .foregroundColor(app.swiftUIColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                
                if let path = app.appPath {
                    Text(path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Custom App Editor View

struct CustomAppEditorView: View {
    @ObservedObject var manager: CustomAppManager
    let app: CustomApp?
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var icon: String = "app"
    @State private var color: String = "blue"
    @State private var appPath: String = ""
    @State private var cliCommand: String = ""
    @State private var usesAppleScript: Bool = false
    @State private var appleScript: String = ""
    
    let availableColors = ["blue", "cyan", "green", "orange", "pink", "purple", "red", "yellow", "gray", "indigo", "mint", "teal"]
    
    let availableIcons = ["terminal", "terminal.fill", "chevron.left.forwardslash.chevron.right", "cursorarrow.rays", "text.cursor", "doc.text", "folder", "hammer", "sparkle", "app", "app.fill", "gearshape", "wrench", "paintbrush", "pencil"]
    
    var isEditing: Bool {
        app != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit App" : "Add Custom App")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Save") {
                    saveApp()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .disabled(name.isEmpty)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("App name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Icon and Color
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Icon")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $icon) {
                                ForEach(availableIcons, id: \.self) { iconName in
                                    Label {
                                        Text(iconName)
                                    } icon: {
                                        Image(systemName: iconName)
                                    }
                                    .tag(iconName)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Color")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $color) {
                                ForEach(availableColors, id: \.self) { colorName in
                                    Text(colorName.capitalized)
                                        .tag(colorName)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // Preview
                    HStack {
                        Text("Preview:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: icon)
                            .foregroundColor(colorFromString(color))
                        Text(name.isEmpty ? "App Name" : name)
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                    
                    Divider()
                    
                    // App Path
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Path (optional)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("/Applications/MyApp.app", text: $appPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Browse") {
                                selectApp()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // CLI Command
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CLI Command (optional)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("myapp", text: $cliCommand)
                            .textFieldStyle(.roundedBorder)
                        Text("Command to run if app not found")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // AppleScript
                    Toggle("Use AppleScript", isOn: $usesAppleScript)
                        .font(.system(size: 12))
                    
                    if usesAppleScript {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AppleScript (use {path} as placeholder)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $appleScript)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 100)
                                .border(Color.secondary.opacity(0.3), width: 1)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 350, height: 500)
        .onAppear {
            if let app = app {
                name = app.name
                icon = app.icon
                color = app.color
                appPath = app.appPath ?? ""
                cliCommand = app.cliCommand ?? ""
                usesAppleScript = app.usesAppleScript
                appleScript = app.appleScript ?? ""
            }
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "cyan": return .cyan
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "indigo": return .indigo
        case "mint": return .mint
        case "teal": return .teal
        default: return .blue
        }
    }
    
    private func selectApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        panel.message = "Choose an application"
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let response = panel.runModal()
        
        if response == .OK, let url = panel.url {
            appPath = url.path
            if name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func saveApp() {
        let newApp = CustomApp(
            id: app?.id ?? UUID(),
            name: name,
            icon: icon,
            color: color,
            appPath: appPath.isEmpty ? nil : appPath,
            cliCommand: cliCommand.isEmpty ? nil : cliCommand,
            isEnabled: app?.isEnabled ?? true,
            usesAppleScript: usesAppleScript,
            appleScript: appleScript.isEmpty ? nil : appleScript
        )
        
        if isEditing {
            manager.updateApp(newApp)
        } else {
            manager.addApp(newApp)
        }
    }
}

// MARK: - Dynamic App Buttons Row

struct DynamicAppButtonsRow: View {
    @ObservedObject var appManager = CustomAppManager.shared
    let path: String
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(appManager.enabledApps) { app in
                AppButton(icon: app.icon, label: app.name, color: app.swiftUIColor) {
                    appManager.openWithApp(app, path: path)
                }
            }
        }
    }
}

// MARK: - Dynamic Mini App Buttons

struct DynamicMiniAppButtons: View {
    @ObservedObject var appManager = CustomAppManager.shared
    let path: String
    let includeFinder: Bool
    
    init(path: String, includeFinder: Bool = false) {
        self.path = path
        self.includeFinder = includeFinder
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if includeFinder {
                MiniAppButton(icon: "folder", color: .gray) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }
                .help("Open in Finder")
            }
            
            ForEach(appManager.enabledApps) { app in
                MiniAppButton(icon: app.icon, color: app.swiftUIColor) {
                    appManager.openWithApp(app, path: path)
                }
                .help("Open in \(app.name)")
            }
        }
    }
}
