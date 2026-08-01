import SwiftUI
import AppKit
import Combine

private enum OverlaySection {
    case windows
    case profiles
}

private final class WindowOverlayModel: ObservableObject {
    @Published var windows: [AppWindow] = []
    @Published var chromeProfiles: [ChromeProfile] = []
    @Published var appName = ""
    @Published var maximumWidth: CGFloat = 900
    @Published var section: OverlaySection = .windows
    @Published var screenCaptureAuthorized = false
    @Published var failedPreviewIDs: Set<CGWindowID> = []
}

private struct OverlayMetrics {
    let compact: Bool

    var cardWidth: CGFloat { compact ? 136 : 190 }
    var previewHeight: CGFloat { compact ? 84 : 118 }
    var titleAreaHeight: CGFloat { compact ? 32 : 40 }
    var cardHeight: CGFloat { previewHeight + titleAreaHeight }
    var profileShortcutWidth: CGFloat { compact ? 72 : 90 }
    var utilityRailWidth: CGFloat { compact ? 34 : 38 }
    var spacing: CGFloat { compact ? 6 : 8 }
    var contentPadding: CGFloat { compact ? 7 : 10 }
    var cornerRadius: CGFloat { compact ? 12 : 15 }
}

private struct TrafficLightButton: View {
    let color: Color
    let symbol: String
    let helpText: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 13, height: 13)

                if hovered {
                    Image(systemName: symbol)
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.72))
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hovered = $0 }
    }
}

private struct WindowStatusBadge: View {
    let symbol: String
    let tint: Color
    let helpText: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.black.opacity(0.62), in: Capsule())
            .help(helpText)
    }
}

private struct ProfileAvatar: View {
    let profile: ChromeProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let image = profile.avatarImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(profileColor.opacity(0.9))
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var profileColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return colors[abs(profile.name.hashValue) % colors.count]
    }
}

private struct SemanticWindowPreview: View {
    let window: AppWindow
    let screenCaptureAuthorized: Bool
    let previewFailed: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.24), Color.black.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: compact ? 6 : 8) {
                if window.isMinimized {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: compact ? 24 : 30, weight: .light))
                        .foregroundStyle(.yellow.opacity(0.86))
                } else if !screenCaptureAuthorized {
                    Image(systemName: "eye.slash")
                        .font(.system(size: compact ? 23 : 29, weight: .light))
                        .foregroundStyle(.white.opacity(0.76))
                } else if previewFailed {
                    Image(systemName: "rectangle.slash")
                        .font(.system(size: compact ? 23 : 29, weight: .light))
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    ProgressView()
                        .controlSize(compact ? .small : .regular)
                        .tint(.white.opacity(0.82))
                }

                Text(detailText)
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var detailText: String {
        if window.isMinimized { return "Minimized" }
        if !screenCaptureAuthorized { return "Enable visual preview" }
        if previewFailed { return "Preview unavailable" }
        return "Loading preview…"
    }

}

private struct WindowPreviewCard: View {
    let window: AppWindow
    let screenCaptureAuthorized: Bool
    let previewFailed: Bool
    let showsMetadata: Bool
    let metrics: OverlayMetrics
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onZoom: () -> Void

    @State private var hovered = false
    @State private var activationTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.42))

                if let image = window.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.cardWidth, height: metrics.previewHeight)
                } else {
                    SemanticWindowPreview(
                        window: window,
                        screenCaptureAuthorized: screenCaptureAuthorized,
                        previewFailed: previewFailed,
                        compact: metrics.compact
                    )
                }

                if hovered, window.axElement != nil {
                    VStack {
                        HStack(spacing: 6) {
                            TrafficLightButton(
                                color: Color(red: 1, green: 0.37, blue: 0.34),
                                symbol: "xmark",
                                helpText: "Close window",
                                action: onClose
                            )
                            TrafficLightButton(
                                color: Color(red: 1, green: 0.74, blue: 0.18),
                                symbol: "minus",
                                helpText: window.isMinimized ? "Restore window" : "Minimize window",
                                action: onMinimize
                            )
                            TrafficLightButton(
                                color: Color(red: 0.20, green: 0.78, blue: 0.35),
                                symbol: "plus",
                                helpText: "Zoom window",
                                action: onZoom
                            )
                            Spacer()
                        }
                        .padding(8)
                        Spacer()
                    }
                }

                VStack {
                    HStack(spacing: 5) {
                        Spacer()
                        if let profile = window.chromeProfile {
                            ProfileAvatar(profile: profile, size: metrics.compact ? 20 : 24)
                                .padding(3)
                                .background(.black.opacity(0.58), in: Circle())
                                .help(profile.name)
                        }
                        if window.isMinimized {
                            WindowStatusBadge(
                                symbol: "arrow.down.right.and.arrow.up.left",
                                tint: .yellow,
                                helpText: "Minimized"
                            )
                        } else if window.isFocused {
                            WindowStatusBadge(
                                symbol: "circle.fill",
                                tint: .blue,
                                helpText: "Active window"
                            )
                        }
                    }
                    .padding(7)
                    Spacer()
                }
            }
            .frame(width: metrics.cardWidth, height: metrics.previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: hovered || window.isFocused ? 1.5 : 1)
            }

            if showsMetadata {
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.title)
                        .font(.system(size: metrics.compact ? 10 : 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(secondaryText)
                        .font(.system(size: metrics.compact ? 8 : 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(width: metrics.cardWidth, height: metrics.titleAreaHeight, alignment: .leading)
                .padding(.horizontal, 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(hovered ? Color.white.opacity(0.075) : Color.clear)
                .padding(-5)
        )
        .onTapGesture(perform: onSelect)
        .onHover(perform: handleHover)
        .onDisappear { activationTask?.cancel() }
        .help(window.title)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showsMetadata ? "\(window.title), \(secondaryText)" : window.title)
        .accessibilityHint("Click to activate this window")
    }

    private var borderColor: Color {
        if hovered { return .accentColor.opacity(0.95) }
        if window.isFocused { return .white.opacity(0.72) }
        if window.isMinimized { return .yellow.opacity(0.42) }
        return .white.opacity(0.14)
    }

    private var secondaryText: String {
        if window.isMinimized { return "Minimized" }
        if let profile = window.chromeProfile { return profile.name }
        if let documentLabel { return documentLabel }
        if window.image == nil {
            if !screenCaptureAuthorized { return "Enable visual preview" }
            return previewFailed ? "Preview unavailable" : "Loading preview…"
        }
        return window.isFocused ? "Active" : "Open"
    }

    private var documentLabel: String? {
        guard let document = window.documentURL, !document.isEmpty else { return nil }
        if document.hasPrefix("/") {
            return URL(fileURLWithPath: document).lastPathComponent
        }
        if let url = URL(string: document) {
            if url.isFileURL { return url.lastPathComponent }
            if let host = url.host, !host.isEmpty {
                return host.replacingOccurrences(of: "www.", with: "")
            }
        }
        return document
    }

    private func handleHover(_ isHovering: Bool) {
        hovered = isHovering
        activationTask?.cancel()

        guard isHovering, DockMonitor.shared.activateOnHover else { return }
        activationTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { onSelect() }
        }
    }
}

private struct UtilityIconButton: View {
    let symbol: String
    let helpText: String
    var tint: Color = .primary
    var selected = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovered ? tint : tint.opacity(0.76))
                .frame(width: 27, height: 25)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected || hovered ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hovered = $0 }
    }
}

private struct UtilityRail: View {
    let metrics: OverlayMetrics
    let showsBack: Bool
    let showsPreviewPermission: Bool
    let showsKill: Bool
    let onBack: () -> Void
    let onRequestVisualPreviews: () -> Void
    let onKill: () -> Void

    private var visibleButtonCount: Int {
        (showsBack ? 1 : 0)
            + (showsPreviewPermission ? 1 : 0)
            + (showsKill ? 1 : 0)
    }

    private var railHeight: CGFloat {
        let count = max(visibleButtonCount, 1)
        return CGFloat(count * 25 + max(count - 1, 0) * 5 + 10)
    }

    var body: some View {
        VStack(spacing: 5) {
            if showsBack {
                UtilityIconButton(
                    symbol: "chevron.left",
                    helpText: "Back to windows",
                    action: onBack
                )
            }

            if showsPreviewPermission {
                UtilityIconButton(
                    symbol: "eye.slash",
                    helpText: "Enable real window previews",
                    tint: .yellow,
                    action: onRequestVisualPreviews
                )
            }

            if showsKill {
                UtilityIconButton(
                    symbol: "power",
                    helpText: "Quit process",
                    tint: .red,
                    action: onKill
                )
            }
        }
        .padding(.vertical, 5)
        .frame(width: metrics.utilityRailWidth, height: railHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10))
        }
    }
}

private struct ProfileShortcutCard: View {
    let profiles: [ChromeProfile]
    let metrics: OverlayMetrics
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    ForEach(Array(profiles.prefix(3).enumerated()), id: \.element.id) { index, profile in
                        ProfileAvatar(profile: profile, size: metrics.compact ? 28 : 34)
                            .overlay(Circle().stroke(Color.black.opacity(0.65), lineWidth: 2))
                            .offset(x: CGFloat(index - 1) * (metrics.compact ? 14 : 17))
                    }
                }
                .frame(height: metrics.compact ? 32 : 38)

                VStack(spacing: 2) {
                    Text("Profiles")
                        .font(.system(size: metrics.compact ? 10 : 11, weight: .medium))
                    Text("New window")
                        .font(.system(size: metrics.compact ? 8 : 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: metrics.profileShortcutWidth, height: metrics.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(hovered ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(hovered ? Color.accentColor.opacity(0.7) : .white.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Open a new browser window with a profile")
    }
}

private struct ChromeProfileCard: View {
    let profile: ChromeProfile
    let metrics: OverlayMetrics
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(profile: profile, size: metrics.compact ? 48 : 58)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                        .background(Circle().fill(.black).padding(2))
                        .offset(x: 3, y: 3)
                }

                Text(profile.name)
                    .font(.system(size: metrics.compact ? 10 : 12, weight: .medium))
                    .lineLimit(1)

                Text("New window")
                    .font(.system(size: metrics.compact ? 8 : 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: metrics.compact ? 82 : 104, height: metrics.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(hovered ? Color.green.opacity(0.13) : Color.white.opacity(0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(hovered ? Color.green.opacity(0.65) : .white.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Open \(profile.name)")
    }
}

private struct WindowOverlayRoot: View {
    @ObservedObject var model: WindowOverlayModel
    @ObservedObject var preferences: DockMonitor

    let onSelect: (AppWindow) -> Void
    let onClose: (AppWindow) -> Void
    let onMinimize: (AppWindow) -> Void
    let onZoom: (AppWindow) -> Void
    let onKill: (AppWindow) -> Void
    let onProfileSelect: (ChromeProfile) -> Void
    let onShowProfiles: () -> Void
    let onBackToWindows: () -> Void
    let onRequestVisualPreviews: () -> Void

    private var metrics: OverlayMetrics {
        OverlayMetrics(compact: preferences.compactOverlayMode)
    }

    var body: some View {
        Group {
            if model.section == .profiles, !model.chromeProfiles.isEmpty {
                profilesContent
            } else {
                windowsContent
            }
        }
        .frame(width: overlayWidth)
        .background {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .compositingGroup()
        .overlay {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    private var windowsContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: metrics.spacing) {
                ForEach(model.windows, id: \.id) { window in
                    WindowPreviewCard(
                        window: window,
                        screenCaptureAuthorized: model.screenCaptureAuthorized,
                        previewFailed: model.failedPreviewIDs.contains(window.id),
                        showsMetadata: showsWindowMetadata,
                        metrics: metrics,
                        onSelect: { onSelect(window) },
                        onClose: { onClose(window) },
                        onMinimize: { onMinimize(window) },
                        onZoom: { onZoom(window) }
                    )
                }

                if !model.chromeProfiles.isEmpty {
                    ProfileShortcutCard(
                        profiles: model.chromeProfiles,
                        metrics: metrics,
                        action: onShowProfiles
                    )
                }

                if SpotifyController.isSpotify(model.appName) {
                    SpotifyMiniPlayerCard()
                        .frame(height: metrics.cardHeight, alignment: .center)
                }

                if CursorController.isCursor(model.appName), preferences.cursorOverlayEnabled {
                    CursorQuickActionsCard()
                        .frame(height: metrics.cardHeight, alignment: .center)
                }

                if showsWindowUtilityRail, let firstWindow = model.windows.first {
                    UtilityRail(
                        metrics: metrics,
                        showsBack: false,
                        showsPreviewPermission: !model.screenCaptureAuthorized,
                        showsKill: preferences.showKillButton,
                        onBack: {},
                        onRequestVisualPreviews: onRequestVisualPreviews,
                        onKill: { onKill(firstWindow) }
                    )
                }
            }
            .padding(metrics.contentPadding)
        }
        .frame(height: windowContentHeight + metrics.contentPadding * 2)
    }

    private var profilesContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: metrics.spacing) {
                if !model.windows.isEmpty {
                    UtilityRail(
                        metrics: metrics,
                        showsBack: true,
                        showsPreviewPermission: false,
                        showsKill: false,
                        onBack: onBackToWindows,
                        onRequestVisualPreviews: {},
                        onKill: {}
                    )
                }

                ForEach(model.chromeProfiles) { profile in
                    ChromeProfileCard(
                        profile: profile,
                        metrics: metrics,
                        action: { onProfileSelect(profile) }
                    )
                }
            }
            .padding(metrics.contentPadding)
        }
        .frame(height: metrics.cardHeight + metrics.contentPadding * 2)
    }

    private var overlayWidth: CGFloat {
        let desired: CGFloat
        if model.section == .profiles {
            let profileWidth: CGFloat = metrics.compact ? 82 : 104
            desired = CGFloat(model.chromeProfiles.count) * profileWidth
                + CGFloat(max(model.chromeProfiles.count - 1, 0)) * metrics.spacing
                + (model.windows.isEmpty ? 0 : metrics.utilityRailWidth + metrics.spacing)
                + metrics.contentPadding * 2
        } else {
            var width = CGFloat(model.windows.count) * metrics.cardWidth
                + CGFloat(max(model.windows.count - 1, 0)) * metrics.spacing

            if !model.chromeProfiles.isEmpty {
                width += metrics.profileShortcutWidth + metrics.spacing
            }
            if SpotifyController.isSpotify(model.appName) {
                width += (metrics.compact ? 180 : 210) + metrics.spacing
            }
            if CursorController.isCursor(model.appName), preferences.cursorOverlayEnabled {
                width += (metrics.compact ? 124 : 148) + metrics.spacing
            }
            if showsWindowUtilityRail {
                width += metrics.utilityRailWidth + metrics.spacing
            }
            desired = width + metrics.contentPadding * 2
        }

        return min(model.maximumWidth, max(metrics.compact ? 156 : 220, desired))
    }

    private var showsWindowUtilityRail: Bool {
        !model.windows.isEmpty
            && (!model.screenCaptureAuthorized || preferences.showKillButton)
    }

    private var showsWindowMetadata: Bool {
        model.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("Google Chrome") == .orderedSame
    }

    private var windowContentHeight: CGFloat {
        if showsWindowMetadata
            || !model.chromeProfiles.isEmpty
            || SpotifyController.isSpotify(model.appName)
            || (CursorController.isCursor(model.appName) && preferences.cursorOverlayEnabled) {
            return metrics.cardHeight
        }
        return metrics.previewHeight
    }
}

private final class DockPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowManager: ObservableObject {
    private let model = WindowOverlayModel()
    private var panel: DockPreviewPanel?
    private var hostingView: NSHostingView<WindowOverlayRoot>?
    private var currentIcon: DockIcon?
    private var windowOrderByApp: [String: [CGWindowID]] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var closeTimer: Timer?
    private var closeDeadline: Date?
    private var closeMonitoringResumeWorkItem: DispatchWorkItem?
    private var previewTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var previewCache: [String: NSImage] = [:]

    init() {
        DockMonitor.shared.$hoveredIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in
                self?.handleIconChange(icon)
            }
            .store(in: &cancellables)

        DockMonitor.shared.$dockIconClicked
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] title in
                guard let self else { return }
                defer { DockMonitor.shared.dockIconClicked = nil }
                guard self.currentIcon?.title == title else { return }
                self.scheduleRefresh(after: 0.35)
            }
            .store(in: &cancellables)

        model.$section
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleLayout()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            DockMonitor.shared.$compactOverlayMode,
            DockMonitor.shared.$showKillButton,
            DockMonitor.shared.$cursorOverlayEnabled
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.scheduleLayout() }
        .store(in: &cancellables)

        DockMonitor.shared.$chromeProfilesEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshCurrentIcon() }
            .store(in: &cancellables)
    }

    deinit {
        closeTimer?.invalidate()
        closeMonitoringResumeWorkItem?.cancel()
        previewTask?.cancel()
    }

    private func handleIconChange(_ icon: DockIcon?) {
        if let icon {
            stopCloseMonitoring()
            let appChanged = currentIcon?.title != icon.title
            currentIcon = icon

            if appChanged || panel?.isVisible != true {
                loadOverlay(for: icon, resetSection: appChanged)
            } else {
                layoutAndPositionPanel()
            }
        } else {
            startCloseMonitoring()
        }
    }

    private func loadOverlay(for icon: DockIcon, resetSection: Bool) {
        refreshGeneration += 1
        let generation = refreshGeneration
        previewTask?.cancel()

        let windows = orderedWindows(WindowFetcher.getWindows(for: icon.title), appName: icon.title)
            .map { window in
                window.replacingImage(previewCache[previewCacheKey(for: window)])
            }
        let profiles = DockMonitor.shared.chromeProfilesEnabled
            ? ChromeProfileFetcher.getProfiles(for: icon.title)
            : []

        guard !windows.isEmpty || !profiles.isEmpty else {
            dismissOverlay(clearIcon: false)
            return
        }

        let runningApp = RunningAppResolver.application(matchingDockTitle: icon.title)
        model.appName = runningApp?.localizedName ?? icon.title
        model.windows = windows
        model.chromeProfiles = profiles
        model.screenCaptureAuthorized = WindowFetcher.isScreenCaptureAuthorized
        model.failedPreviewIDs = []

        if resetSection {
            model.section = windows.isEmpty && !profiles.isEmpty ? .profiles : .windows
        } else if model.section == .profiles && profiles.isEmpty {
            model.section = .windows
        }

        makePanelIfNeeded()
        layoutAndPositionPanel()
        panel?.orderFrontRegardless()

        guard WindowFetcher.isScreenCaptureAuthorized, !windows.isEmpty else { return }
        startPreviewCapture(for: windows, generation: generation)
    }

    private func orderedWindows(_ windows: [AppWindow], appName: String) -> [AppWindow] {
        let savedOrder = windowOrderByApp[appName] ?? []
        var pool = windows
        var result: [AppWindow] = []

        for id in savedOrder {
            if let index = pool.firstIndex(where: { $0.id == id }) {
                result.append(pool.remove(at: index))
            }
        }
        result.append(contentsOf: pool)
        windowOrderByApp[appName] = result.map(\.id)
        return result
    }

    private func previewCacheKey(for window: AppWindow) -> String {
        "\(window.ownerPID)-\(window.id)"
    }

    private func startPreviewCapture(for windows: [AppWindow], generation: Int) {
        let capturableWindows = windows.filter { !$0.isMinimized }
        guard !capturableWindows.isEmpty else { return }

        previewTask = Task { [weak self] in
            let previews = await WindowFetcher.capturePreviews(for: capturableWindows)
            guard let self, !Task.isCancelled, generation == self.refreshGeneration else { return }

            for window in capturableWindows {
                if let image = previews[window.id] {
                    self.previewCache[self.previewCacheKey(for: window)] = image
                }
            }
            if self.previewCache.count > 80 {
                let keysToRemove = Array(
                    self.previewCache.keys.prefix(self.previewCache.count - 80)
                )
                for key in keysToRemove {
                    self.previewCache.removeValue(forKey: key)
                }
            }

            self.model.windows = self.model.windows.map { window in
                if let image = previews[window.id] {
                    return window.replacingImage(image)
                }
                return window
            }

            let unresolved = capturableWindows.filter { window in
                previews[window.id] == nil
                    && self.previewCache[self.previewCacheKey(for: window)] == nil
            }
            self.model.failedPreviewIDs = Set(unresolved.map(\.id))
            self.scheduleLayout()
        }
    }

    private func retryPreview(for window: AppWindow) {
        guard WindowFetcher.isScreenCaptureAuthorized, !window.isMinimized else { return }

        previewTask?.cancel()
        let generation = refreshGeneration
        model.failedPreviewIDs.remove(window.id)

        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            let previews = await WindowFetcher.capturePreviews(for: [window])
            guard let self, !Task.isCancelled, generation == self.refreshGeneration else { return }

            if let image = previews[window.id] {
                self.previewCache[self.previewCacheKey(for: window)] = image
                self.model.failedPreviewIDs.remove(window.id)
                self.model.windows = self.model.windows.map {
                    $0.id == window.id ? $0.replacingImage(image) : $0
                }
            } else {
                self.model.failedPreviewIDs.insert(window.id)
            }
            self.panel?.orderFrontRegardless()
            self.scheduleLayout()
        }
    }

    private func makePanelIfNeeded() {
        guard panel == nil else { return }

        let rootView = WindowOverlayRoot(
            model: model,
            preferences: DockMonitor.shared,
            onSelect: { [weak self] in self?.selectWindow($0) },
            onClose: { [weak self] in self?.performWindowAction(.close, window: $0) },
            onMinimize: { [weak self] in self?.performWindowAction(.minimize, window: $0) },
            onZoom: { [weak self] in self?.performWindowAction(.zoom, window: $0) },
            onKill: { [weak self] in self?.killProcess(for: $0) },
            onProfileSelect: { [weak self] in self?.openProfile($0) },
            onShowProfiles: { [weak self] in self?.changeSection(to: .profiles) },
            onBackToWindows: { [weak self] in self?.changeSection(to: .windows) },
            onRequestVisualPreviews: { [weak self] in self?.requestVisualPreviews() }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        let panel = DockPreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [
            .transient,
            .canJoinAllSpaces,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        panel.isMovable = false

        self.hostingView = hostingView
        self.panel = panel
    }

    private enum WindowAction {
        case close
        case minimize
        case zoom
    }

    private func selectWindow(_ window: AppWindow) {
        suspendAutoClose(for: 0.45)
        model.windows = model.windows.map { $0.replacingFocus($0.id == window.id) }
        WindowFetcher.activateWindow(window: window)
        panel?.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.panel?.orderFrontRegardless()
        }
        retryPreview(for: window)
    }

    private func changeSection(to section: OverlaySection) {
        guard model.section != section else { return }
        suspendAutoClose(for: 0.7)
        model.section = section

        DispatchQueue.main.async { [weak self] in
            self?.layoutAndPositionPanel()
            self?.panel?.orderFrontRegardless()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.layoutAndPositionPanel()
            self?.panel?.orderFrontRegardless()
        }
    }

    private func performWindowAction(_ action: WindowAction, window: AppWindow) {
        switch action {
        case .close:
            WindowFetcher.closeWindow(window: window)
        case .minimize:
            WindowFetcher.minimizeWindow(window: window)
        case .zoom:
            WindowFetcher.toggleFullscreen(window: window)
        }
        scheduleRefresh(after: action == .zoom ? 0.5 : 0.3)
    }

    private func killProcess(for window: AppWindow) {
        WindowFetcher.killProcess(window: window)
        dismissOverlay(clearIcon: true)
    }

    private func openProfile(_ profile: ChromeProfile) {
        guard let icon = currentIcon else { return }
        suspendAutoClose(for: 1.0)
        panel?.orderFrontRegardless()
        ChromeProfileFetcher.openNewWindow(for: icon.title, profile: profile)
        scheduleRefresh(after: 0.65)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.panel?.orderFrontRegardless()
        }
    }

    private func requestVisualPreviews() {
        let granted = CGRequestScreenCaptureAccess()
        model.screenCaptureAuthorized = granted || WindowFetcher.isScreenCaptureAuthorized

        if model.screenCaptureAuthorized {
            refreshCurrentIcon()
            return
        }

        if let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) {
            NSWorkspace.shared.open(settingsURL)
        }
    }

    private func scheduleRefresh(after delay: TimeInterval) {
        let expectedTitle = currentIcon?.title
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let icon = self.currentIcon, icon.title == expectedTitle else { return }
            self.loadOverlay(for: icon, resetSection: false)
        }
    }

    private func refreshCurrentIcon() {
        guard let icon = currentIcon, panel?.isVisible == true else { return }
        loadOverlay(for: icon, resetSection: false)
    }

    private func scheduleLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.layoutAndPositionPanel()
        }
    }

    private func layoutAndPositionPanel() {
        guard let panel, let hostingView, let icon = currentIcon else { return }
        let anchor = anchorContext(for: icon)
        model.maximumWidth = max(260, anchor.screen.visibleFrame.width - 24)

        // NSHostingView is rectangular even when SwiftUI clips its contents. Mask
        // the AppKit layer too so visual-effect materials cannot leak into the
        // transparent corners of the borderless panel.
        hostingView.layer?.cornerRadius = DockMonitor.shared.compactOverlayMode ? 12 : 15
        hostingView.layer?.masksToBounds = true

        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()

        var size = hostingView.fittingSize
        size.width = min(size.width, model.maximumWidth)
        size.height = max(size.height, 100)
        panel.setContentSize(size)

        let visible = anchor.screen.visibleFrame
        let gap: CGFloat = 8
        let distances = [
            (DockEdge.bottom, abs(anchor.iconRect.minY - anchor.screen.frame.minY)),
            (DockEdge.left, abs(anchor.iconRect.minX - anchor.screen.frame.minX)),
            (DockEdge.right, abs(anchor.screen.frame.maxX - anchor.iconRect.maxX))
        ]
        let edge = distances.min(by: { $0.1 < $1.1 })?.0 ?? .bottom

        var origin: CGPoint
        switch edge {
        case .bottom:
            origin = CGPoint(
                x: anchor.iconRect.midX - size.width / 2,
                y: anchor.iconRect.maxY + gap
            )
        case .left:
            origin = CGPoint(
                x: anchor.iconRect.maxX + gap,
                y: anchor.iconRect.midY - size.height / 2
            )
        case .right:
            origin = CGPoint(
                x: anchor.iconRect.minX - size.width - gap,
                y: anchor.iconRect.midY - size.height / 2
            )
        }

        origin.x = min(max(origin.x, visible.minX + 6), visible.maxX - size.width - 6)
        origin.y = min(max(origin.y, visible.minY + 6), visible.maxY - size.height - 6)
        panel.setFrameOrigin(origin)
    }

    private enum DockEdge {
        case bottom
        case left
        case right
    }

    private struct AnchorContext {
        let screen: NSScreen
        let iconRect: CGRect
    }

    private func anchorContext(for icon: DockIcon) -> AnchorContext {
        let desktopTop = NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
        let cocoaRect = CGRect(
            x: icon.frame.minX,
            y: desktopTop - icon.frame.maxY,
            width: icon.frame.width,
            height: icon.frame.height
        )
        let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: cocoaRect.midX, y: cocoaRect.midY)) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        return AnchorContext(screen: screen, iconRect: cocoaRect)
    }

    private func startCloseMonitoring() {
        guard panel?.isVisible == true else { return }
        if closeDeadline == nil {
            closeDeadline = Date().addingTimeInterval(0.22)
        }
        guard closeTimer == nil else { return }

        closeTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkWhetherToClose() }
        }
        if let closeTimer {
            RunLoop.main.add(closeTimer, forMode: .common)
        }
    }

    private func stopCloseMonitoring() {
        closeTimer?.invalidate()
        closeTimer = nil
        closeDeadline = nil
    }

    private func suspendAutoClose(for duration: TimeInterval) {
        closeMonitoringResumeWorkItem?.cancel()
        stopCloseMonitoring()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.panel?.isVisible == true else { return }
            self.panel?.orderFrontRegardless()
            self.startCloseMonitoring()
        }
        closeMonitoringResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func checkWhetherToClose() {
        guard DockMonitor.shared.hoveredIcon == nil else {
            closeDeadline = nil
            return
        }
        guard let panel, panel.isVisible else {
            stopCloseMonitoring()
            return
        }

        let hoverArea = panel.frame.insetBy(dx: -7, dy: -7)
        if hoverArea.contains(NSEvent.mouseLocation) {
            closeDeadline = nil
            return
        }

        if closeDeadline == nil {
            closeDeadline = Date().addingTimeInterval(0.16)
        }
        if let closeDeadline, Date() >= closeDeadline {
            dismissOverlay(clearIcon: true)
        }
    }

    private func dismissOverlay(clearIcon: Bool) {
        refreshGeneration += 1
        previewTask?.cancel()
        previewTask = nil
        closeMonitoringResumeWorkItem?.cancel()
        closeMonitoringResumeWorkItem = nil
        stopCloseMonitoring()
        panel?.orderOut(nil)

        if clearIcon {
            currentIcon = nil
            model.windows = []
            model.chromeProfiles = []
            model.appName = ""
            model.section = .windows
            model.screenCaptureAuthorized = WindowFetcher.isScreenCaptureAuthorized
            model.failedPreviewIDs = []
        }
    }
}
