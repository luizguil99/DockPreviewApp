import SwiftUI
import AppKit
import Combine

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
    let onKill: () -> Void
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
                            
                            // Kill process button (right side)
                            WindowControlButton(color: Color(red: 0.6, green: 0.1, blue: 0.1), systemName: "power") {
                                onKill()
                            }
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

struct PreviewOverlay: View {
    let windows: [AppWindow]
    let onSelect: (AppWindow) -> Void
    let onClose: (AppWindow) -> Void
    let onMinimize: (AppWindow) -> Void
    let onFullscreen: (AppWindow) -> Void
    let onKill: (AppWindow) -> Void
    let maxWidth: CGFloat
    
    var body: some View {
        Group {
            if windows.isEmpty {
                Text("No open windows")
                    .foregroundColor(.white)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(windows, id: \.id) { window in
                            WindowPreviewCard(
                                window: window,
                                onSelect: { onSelect(window) },
                                onClose: { onClose(window) },
                                onMinimize: { onMinimize(window) },
                                onFullscreen: { onFullscreen(window) },
                                onKill: { onKill(window) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: maxWidth)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .shadow(radius: 10)
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
    private var cancellables = Set<AnyCancellable>()
    private var checkTimer: Timer?
    private var isRefreshing = false // Flag to prevent closing during refresh
    
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
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIconChange(_ icon: DockIcon?) {
        // Don't change icon while refreshing
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
    
    private func updateOverlay() {
        guard let icon = currentIcon else {
            print("Cleaning up panel (no icon)")
            panel?.orderOut(nil)
            panel = nil
            return
        }
        
        print("Update Overlay for icon: \(icon.title)")
        
        // Fetch windows
        let windows = WindowFetcher.getWindows(for: icon.title)
        
        if windows.isEmpty {
             print("No windows found for \(icon.title)")
             panel?.orderOut(nil)
             // panel = nil // Keep panel? No, hide it.
             return
        }

        // Create Panel if needed
        if panel == nil {
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
        }
        
        // Position above the dock icon - RESPONSIVE (don't go off screen)
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let screenHeight = screen.frame.height
        
        // Calculate max width for the overlay (screen width minus margins)
        let maxPanelWidth = screenFrame.width - 32 // 16px margin on each side
        
        let contentView = PreviewOverlay(
            windows: windows,
            onSelect: { [weak self] window in
                self?.isRefreshing = true
                WindowFetcher.activateWindow(window: window)
                // Refresh overlay after a short delay to capture updated window image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.updateOverlay()
                    self?.isRefreshing = false
                }
            },
            onClose: { [weak self] window in
                WindowFetcher.closeWindow(window: window)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.updateOverlay()
                }
            },
            onMinimize: { [weak self] window in
                self?.isRefreshing = true
                WindowFetcher.minimizeWindow(window: window)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.updateOverlay()
                    self?.isRefreshing = false
                }
            },
            onFullscreen: { [weak self] window in
                self?.isRefreshing = true
                WindowFetcher.toggleFullscreen(window: window)
                // Refresh after fullscreen to capture new size
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateOverlay()
                    self?.isRefreshing = false
                }
            },
            onKill: { [weak self] window in
                WindowFetcher.killProcess(window: window)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.updateOverlay()
                }
            },
            maxWidth: maxPanelWidth
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        panel?.contentView = hostingView
        
        // Size the panel to fit content (but respect max width)
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
