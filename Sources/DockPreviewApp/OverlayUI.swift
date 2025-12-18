import SwiftUI
import AppKit
import Combine

// Observable model to hold windows data without recreating views
class WindowsModel: ObservableObject {
    @Published var windows: [AppWindow] = []
    @Published var chromeProfiles: [ChromeProfile] = []
    @Published var appName: String = ""
    @Published var showOnlyProfiles: Bool = false  // Toggle to show only profiles view
}

struct WindowControlButton: View {
    let color: Color
    let systemName: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                
                if isHovered {
                    Image(systemName: systemName)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WindowPreviewCard: View {
    let window: AppWindow
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onFullscreen: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Window preview image
                if let nsImage = window.image {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isHovered ? Color.blue : (window.isMinimized ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2)),
                                    lineWidth: isHovered ? 2 : (window.isMinimized ? 2 : 1)
                                )
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 160, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isHovered ? Color.blue : Color.white.opacity(0.2), lineWidth: isHovered ? 2 : 1)
                        )
                }
                
                // Traffic light buttons (top-left) - only show on hover
                if isHovered {
                    VStack {
                        HStack(spacing: 4) {
                            WindowControlButton(color: .red, systemName: "xmark") {
                                onClose()
                            }
                            WindowControlButton(color: .yellow, systemName: "minus") {
                                onMinimize()
                            }
                            WindowControlButton(color: .green, systemName: "arrow.up.left.and.arrow.down.right") {
                                onFullscreen()
                            }
                            Spacer()
                        }
                        .padding(6)
                        Spacer()
                    }
                    .frame(width: 160, height: 100)
                }
                
                // Minimized badge (top-right)
                if window.isMinimized {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.yellow)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .font(.system(size: 16))
                                .padding(4)
                        }
                        Spacer()
                    }
                    .frame(width: 160, height: 100)
                }
            }
            
            HStack(spacing: 4) {
                if window.isMinimized {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
                Text(window.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(window.isMinimized ? .yellow : .white)
            }
            .frame(width: 160)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.blue.opacity(0.3) : Color.black.opacity(window.isMinimized ? 0.7 : 0.5))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// Kill Process Button - small icon button
struct KillProcessButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isHovered ? Color.red.opacity(0.3) : Color.white.opacity(0.1))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isHovered ? Color.red : Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Image(systemName: "power")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .red : .white.opacity(0.6))
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

// Add Profile Button - appears at the end of Chrome windows
struct AddProfileButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background matching window preview style
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 80, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.green : Color.white.opacity(0.3), lineWidth: isHovered ? 2 : 1)
                    )
                
                // Plus icon
                VStack(spacing: 4) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(isHovered ? .green : .white.opacity(0.7))
                    
                    Text("Profiles")
                        .font(.system(size: 10))
                        .foregroundColor(isHovered ? .green : .white.opacity(0.6))
                }
            }
            
            Text("New Window")
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(isHovered ? .green : .white.opacity(0.7))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.green.opacity(0.2) : Color.black.opacity(0.3))
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

// Back button to return from profiles-only view
struct BackToWindowsButton: View {
    let windowCount: Int
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .semibold))
            
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 11))
            
            Text("\(windowCount) window\(windowCount == 1 ? "" : "s")")
                .font(.system(size: 11))
        }
        .foregroundColor(isHovered ? .blue : .white.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

// Large Chrome Profile Card (for profiles-only view)
struct ProfileCardLarge: View {
    let profile: ChromeProfile
    let appName: String
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile avatar - larger
            ZStack(alignment: .bottomTrailing) {
                if let avatar = profile.avatarImage {
                    Image(nsImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isHovered ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Circle()
                                .stroke(isHovered ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                        )
                }
                
                // Plus badge
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.black.opacity(0.9)).frame(width: 14, height: 14))
                    .offset(x: 4, y: 4)
            }
            
            Text(profile.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundColor(isHovered ? .green : .white)
        }
        .frame(width: 90)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.green.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Profiles Overlay Component
// Separate overlay that shows all Chrome profiles in a single row
struct ProfilesOverlay: View {
    let profiles: [ChromeProfile]
    let appName: String
    let windowCount: Int
    let onProfileSelect: (ChromeProfile) -> Void
    let onBack: () -> Void
    
    // Calculate width based on number of profiles
    private var calculatedWidth: CGFloat {
        // Each profile card is 90px wide + 12px horizontal padding each side = 114px
        // Plus 10px spacing between cards
        // Plus 24px outer padding (12 each side)
        let cardWidth: CGFloat = 114
        let spacing: CGFloat = 10
        let outerPadding: CGFloat = 24
        
        let totalWidth = (cardWidth * CGFloat(profiles.count)) + (spacing * CGFloat(max(0, profiles.count - 1))) + outerPadding
        return max(totalWidth, 200) // Minimum width
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Header with back button
            HStack {
                if windowCount > 0 {
                    BackToWindowsButton(windowCount: windowCount) {
                        onBack()
                    }
                }
                
                Spacer()
                
                Text("Open New Window")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Spacer to balance the back button
                if windowCount > 0 {
                    Color.clear.frame(width: 100)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            // Profiles row - all profiles in a single row (no scroll)
            HStack(spacing: 10) {
                ForEach(profiles) { profile in
                    ProfileCardLarge(
                        profile: profile,
                        appName: appName,
                        onSelect: { onProfileSelect(profile) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: calculatedWidth)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Windows Preview Overlay
// Shows only Chrome/app windows with an optional button to open profiles overlay
struct WindowsPreviewOverlay: View {
    @ObservedObject var windowsModel: WindowsModel
    let onSelect: (AppWindow) -> Void
    let onClose: (AppWindow) -> Void
    let onMinimize: (AppWindow) -> Void
    let onFullscreen: (AppWindow) -> Void
    let onKill: (AppWindow) -> Void
    let maxWidth: CGFloat
    
    var hasProfiles: Bool {
        !windowsModel.chromeProfiles.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !windowsModel.windows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(windowsModel.windows, id: \.id) { window in
                            WindowPreviewCard(
                                window: window,
                                onSelect: { onSelect(window) },
                                onClose: { onClose(window) },
                                onMinimize: { onMinimize(window) },
                                onFullscreen: { onFullscreen(window) }
                            )
                        }
                        
                        // Add profile button for Chromium browsers
                        if hasProfiles {
                            AddProfileButton {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    windowsModel.showOnlyProfiles = true
                                }
                            }
                        }
                        
                        // Kill process button - small icon (centered vertically, after profiles)
                        VStack {
                            Spacer()
                            KillProcessButton {
                                // Kill the first window's process (they all share the same PID)
                                if let firstWindow = windowsModel.windows.first {
                                    onKill(firstWindow)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            } else {
                Text("No open windows")
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .frame(maxWidth: maxWidth)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

struct PreviewOverlay: View {
    @ObservedObject var windowsModel: WindowsModel
    let onSelect: (AppWindow) -> Void
    let onClose: (AppWindow) -> Void
    let onMinimize: (AppWindow) -> Void
    let onFullscreen: (AppWindow) -> Void
    let onKill: (AppWindow) -> Void
    let onProfileSelect: (ChromeProfile) -> Void
    let maxWidth: CGFloat
    
    var hasProfiles: Bool {
        !windowsModel.chromeProfiles.isEmpty
    }
    
    var body: some View {
        // Show profiles overlay or windows overlay based on state
        if windowsModel.showOnlyProfiles && hasProfiles {
            ProfilesOverlay(
                profiles: windowsModel.chromeProfiles,
                appName: windowsModel.appName,
                windowCount: windowsModel.windows.count,
                onProfileSelect: onProfileSelect,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        windowsModel.showOnlyProfiles = false
                    }
                }
            )
        } else if windowsModel.windows.isEmpty && hasProfiles {
            // No windows but has profiles - show profiles directly
            ProfilesOverlay(
                profiles: windowsModel.chromeProfiles,
                appName: windowsModel.appName,
                windowCount: 0,
                onProfileSelect: onProfileSelect,
                onBack: {}
            )
        } else {
            WindowsPreviewOverlay(
                windowsModel: windowsModel,
                onSelect: onSelect,
                onClose: onClose,
                onMinimize: onMinimize,
                onFullscreen: onFullscreen,
                onKill: onKill,
                maxWidth: maxWidth
            )
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

class OverlayWindowManager: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<PreviewOverlay>?
    private var windowsModel = WindowsModel()
    private var cancellables = Set<AnyCancellable>()
    private var checkTimer: Timer?
    private var isRefreshing = false // Flag to prevent closing during refresh
    private var lastAppName: String = "" // Track app to force panel recreation on app change
    
    init() {
        // Setup subscribers - use shared DockMonitor
        DockMonitor.shared.$hoveredIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in
                self?.handleIconChange(icon)
            }
            .store(in: &cancellables)
        
        // Listen for dock icon clicks to refresh overlay
        DockMonitor.shared.$dockIconClicked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] clickedIconTitle in
                guard let clickedIconTitle = clickedIconTitle,
                      let self = self,
                      let currentIcon = self.currentIcon,
                      currentIcon.title == clickedIconTitle else { return }
                
                print("Dock icon clicked: \(clickedIconTitle) - will refresh overlay")
                self.isRefreshing = true
                
                // Refresh overlay after a delay to capture updated window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.updateOverlay()
                    self.isRefreshing = false
                    // Reset the clicked state
                    DockMonitor.shared.dockIconClicked = nil
                    
                    // IMPORTANT: Check if we should close the overlay now
                    // (in case hoveredIcon became nil while we were refreshing)
                    if DockMonitor.shared.hoveredIcon == nil {
                        self.startCheckTimer()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for profile view toggle to resize panel
        windowsModel.$showOnlyProfiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Small delay to let SwiftUI update the view first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.resizePanel()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIconChange(_ icon: DockIcon?) {
        // Don't change icon while refreshing - but we'll check again after refresh ends
        if isRefreshing && icon == nil {
            return
        }
        
        if let newIcon = icon {
            // New icon hovered, switch immediately
            self.currentIcon = newIcon
            stopCheckTimer()
        } else {
            // Mouse left the icon. Check if it's over the panel.
            startCheckTimer()
        }
    }
    
    private func startCheckTimer() {
        stopCheckTimer()
        // Check frequently if mouse is still over panel
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouseOverPanel()
        }
    }
    
    private func stopCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func checkMouseOverPanel() {
        // Don't close while refreshing
        if isRefreshing {
            return
        }
        
        guard let panel = panel, panel.isVisible else {
            // Panel not visible, just clear
            self.currentIcon = nil
            stopCheckTimer()
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        // Check if mouseLoc is inside panel frame
        // Panel frame is in screen coordinates (bottom-left origin for Cocoa)
        // NSEvent.mouseLocation is also bottom-left.
        if panel.frame.contains(mouseLoc) {
            // Still hovering panel, keep it alive
            return
        }
        
        // Also check if mouse is back over the current icon (DockMonitor should handle this, 
        // but if there's a gap between icon and panel, we might lose it. 
        // But DockMonitor would report the icon if it was over the icon.
        // So if we are here, DockMonitor says NO icon, and we say NO panel.
        
        // Add a small buffer/delay or frame expansion?
        // For now, strict check.
        
        self.currentIcon = nil
        stopCheckTimer()
    }
    
    @Published var currentIcon: DockIcon? {
        didSet {
            updateOverlay()
        }
    }
    
    private func resizePanel() {
        guard let panel = panel, let hostingView = hostingView, let icon = currentIcon else { return }
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let screenHeight = screen.frame.height
        let maxPanelWidth = screenFrame.width - 32
        
        // Force layout update to get correct size
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        
        // Recalculate fitting size
        var fittingSize = hostingView.fittingSize
        if fittingSize.width > maxPanelWidth {
            fittingSize.width = maxPanelWidth
        }
        
        panel.setContentSize(fittingSize)
        
        // Recalculate position (centered above icon)
        let iconCocoaY = screenHeight - (icon.frame.origin.y + icon.frame.height)
        let iconCocoaX = icon.frame.origin.x
        
        var panelX = iconCocoaX + (icon.frame.width / 2) - (fittingSize.width / 2)
        let panelY = iconCocoaY + icon.frame.height + 10
        
        // Clamp X to stay within screen bounds
        let minX = screenFrame.origin.x + 8
        let maxX = screenFrame.origin.x + screenFrame.width - fittingSize.width - 8
        panelX = max(minX, min(panelX, maxX))
        
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }
    
    private func updateOverlay() {
        guard let icon = currentIcon else {
            print("Cleaning up panel (no icon)")
            panel?.orderOut(nil)
            panel = nil
            hostingView = nil
            windowsModel.windows = []
            windowsModel.chromeProfiles = []
            windowsModel.appName = ""
            windowsModel.showOnlyProfiles = false  // Reset profiles-only mode
            lastAppName = ""
            return
        }
        
        print("Update Overlay for icon: \(icon.title)")
        
        // Check if app changed - force panel recreation
        let appChanged = lastAppName != icon.title
        if appChanged {
            print("App changed from '\(lastAppName)' to '\(icon.title)' - recreating panel")
            panel?.orderOut(nil)
            panel = nil
            hostingView = nil
            windowsModel.windows = []
            windowsModel.chromeProfiles = []
            windowsModel.showOnlyProfiles = false  // Reset profiles-only mode on app change
            lastAppName = icon.title
        }
        
        // Fetch windows
        let windows = WindowFetcher.getWindows(for: icon.title)
        
        // Fetch Chrome profiles if enabled and applicable
        let profiles: [ChromeProfile]
        if DockMonitor.shared.chromeProfilesEnabled {
            profiles = ChromeProfileFetcher.getProfiles(for: icon.title)
        } else {
            profiles = []
        }
        
        // Show overlay if we have windows OR profiles (for Chromium browsers)
        if windows.isEmpty && profiles.isEmpty {
             print("No windows or profiles found for \(icon.title)")
             panel?.orderOut(nil)
             return
        }

        // Position above the dock icon - RESPONSIVE (don't go off screen)
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let screenHeight = screen.frame.height
        
        // Calculate max width for the overlay (screen width minus margins)
        let maxPanelWidth = screenFrame.width - 32 // 16px margin on each side

        // Create Panel and HostingView if needed
        let needsNewPanel = panel == nil || hostingView == nil
        
        if needsNewPanel {
            print("Creating new panel")
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel?.level = .floating
            panel?.backgroundColor = .clear
            panel?.isOpaque = false
            panel?.hasShadow = true
            
            // Create hosting view with observable model (only once)
            let contentView = PreviewOverlay(
                windowsModel: windowsModel,
                onSelect: { [weak self] window in
                    self?.isRefreshing = true
                    WindowFetcher.activateWindow(window: window)
                    // Refresh overlay after a short delay to capture updated window image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self?.updateOverlay()
                        self?.isRefreshing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.resizePanel()
                        }
                    }
                },
                onClose: { [weak self] window in
                    WindowFetcher.closeWindow(window: window)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.updateOverlay()
                        // Force resize after SwiftUI updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.resizePanel()
                        }
                    }
                },
                onMinimize: { [weak self] window in
                    self?.isRefreshing = true
                    WindowFetcher.minimizeWindow(window: window)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.updateOverlay()
                        self?.isRefreshing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.resizePanel()
                        }
                    }
                },
                onFullscreen: { [weak self] window in
                    self?.isRefreshing = true
                    WindowFetcher.toggleFullscreen(window: window)
                    // Refresh after fullscreen to capture new size
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.updateOverlay()
                        self?.isRefreshing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.resizePanel()
                        }
                    }
                },
                onKill: { [weak self] window in
                    WindowFetcher.killProcess(window: window)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.updateOverlay()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.resizePanel()
                        }
                    }
                },
                onProfileSelect: { [weak self] profile in
                    guard let self = self, let appName = self.currentIcon?.title else { return }
                    ChromeProfileFetcher.openNewWindow(for: appName, profile: profile)
                    // Refresh overlay after opening new window
                    self.isRefreshing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.updateOverlay()
                        self.isRefreshing = false
                        // Force resize after SwiftUI updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.resizePanel()
                        }
                    }
                },
                maxWidth: maxPanelWidth
            )
            
            hostingView = NSHostingView(rootView: contentView)
            panel?.contentView = hostingView
        }
        
        // Update the windows model (this preserves hover states in existing views)
        windowsModel.windows = windows
        windowsModel.chromeProfiles = profiles
        windowsModel.appName = icon.title
        
        // Size the panel to fit content (but respect max width)
        guard let hostingView = hostingView else { return }
        
        // Force layout update before calculating size
        hostingView.layoutSubtreeIfNeeded()
        
        var fittingSize = hostingView.fittingSize
        if fittingSize.width > maxPanelWidth {
            fittingSize.width = maxPanelWidth
        }
        panel?.setContentSize(fittingSize)
        
        // icon.frame.origin.y is distance from top (AX/Quartz).
        // Cocoa y = screenHeight - (iconY + iconHeight)
        let iconCocoaY = screenHeight - (icon.frame.origin.y + icon.frame.height)
        let iconCocoaX = icon.frame.origin.x
        
        // Calculate ideal position (centered above icon)
        var panelX = iconCocoaX + (icon.frame.width / 2) - (fittingSize.width / 2)
        let panelY = iconCocoaY + icon.frame.height + 10 // 10px padding above icon
        
        // Clamp X to stay within screen bounds
        let minX = screenFrame.origin.x + 8
        let maxX = screenFrame.origin.x + screenFrame.width - fittingSize.width - 8
        
        panelX = max(minX, min(panelX, maxX))
        
        print("Positioning panel at: \(panelX), \(panelY) (panel width: \(fittingSize.width))")
        panel?.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        
        panel?.orderFront(nil)
    }
}
