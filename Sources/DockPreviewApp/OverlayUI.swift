import SwiftUI
import AppKit
import Combine

struct PreviewOverlay: View {
    let windows: [AppWindow]
    let onSelect: (AppWindow) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if windows.isEmpty {
                Text("No open windows")
                    .foregroundColor(.white)
                    .padding()
            } else {
                ForEach(windows, id: \.id) { window in
                    VStack {
                        ZStack(alignment: .topTrailing) {
                            if let nsImage = window.image {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 160, height: 100)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(window.isMinimized ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2), lineWidth: window.isMinimized ? 2 : 1)
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 160, height: 100)
                                    .cornerRadius(8)
                            }
                            
                            // Minimized badge
                            if window.isMinimized {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.yellow)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .font(.system(size: 18))
                                    .offset(x: 4, y: -4)
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
                    .background(Color.black.opacity(window.isMinimized ? 0.7 : 0.6))
                    .cornerRadius(12)
                    .onTapGesture {
                        onSelect(window)
                    }
                }
            }
        }
        .padding(12)
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
    
    init() {
        // Setup subscribers - use shared DockMonitor
        DockMonitor.shared.$hoveredIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in
                self?.handleIconChange(icon)
            }
            .store(in: &cancellables)
    }
    
    private func handleIconChange(_ icon: DockIcon?) {
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
        
        let contentView = PreviewOverlay(windows: windows) { window in
            WindowFetcher.activateWindow(window: window)
            // Optional: hide overlay immediately
            // self.panel?.orderOut(nil)
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        panel?.contentView = hostingView
        
        // Size the panel to fit content
        let fittingSize = hostingView.fittingSize
        panel?.setContentSize(fittingSize)
        
        // Position above the dock icon
        if let screen = NSScreen.main {
            let screenHeight = screen.frame.height
            // icon.frame.origin.y is distance from top (AX/Quartz).
            // Cocoa y = screenHeight - (iconY + iconHeight)
            let iconCocoaY = screenHeight - (icon.frame.origin.y + icon.frame.height)
            let iconCocoaX = icon.frame.origin.x
            
            let panelX = iconCocoaX + (icon.frame.width / 2) - (fittingSize.width / 2)
            let panelY = iconCocoaY + icon.frame.height + 10 // 10px padding above icon
            
            print("Positioning panel at: \(panelX), \(panelY)")
            panel?.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }
        
        panel?.orderFront(nil)
    }
}
