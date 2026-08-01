import SwiftUI
import AppKit

// MARK: - Spotify Data Model
@MainActor
final class SpotifyState: ObservableObject {
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var albumArt: NSImage?
    @Published var isPlaying: Bool = false
    @Published var position: Double = 0  // in seconds
    @Published var duration: Double = 0  // in seconds
    @Published var isLiked: Bool = false

    private struct Snapshot {
        let trackName: String
        let artistName: String
        let artworkURL: String
        let isPlaying: Bool
        let position: Double
        let duration: Double
    }

    private var clockTimer: Timer?
    private var syncTimer: Timer?
    private var lastClockUpdate = Date()
    private var refreshInFlight = false
    private var currentArtworkURL = ""

    func startUpdating() {
        guard clockTimer == nil, syncTimer == nil else { return }
        lastClockUpdate = Date()
        refresh()

        let clock = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceClock(to: Date())
            }
        }
        RunLoop.main.add(clock, forMode: .common)
        clockTimer = clock

        let sync = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(sync, forMode: .common)
        syncTimer = sync
    }

    func stopUpdating() {
        clockTimer?.invalidate()
        syncTimer?.invalidate()
        clockTimer = nil
        syncTimer = nil
    }

    func setPlayingOptimistically(_ playing: Bool) {
        advanceClock(to: Date())
        isPlaying = playing
        lastClockUpdate = Date()
    }

    func refresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true

        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "Spotify"
                if player state is playing then
                    set isPlaying to true
                else
                    set isPlaying to false
                end if
                set trackName to name of current track
                set artistName to artist of current track
                set artworkUrl to artwork url of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                return {trackName, artistName, artworkUrl, isPlaying, trackPosition, trackDuration}
            end tell
            """

            var error: NSDictionary?
            var snapshot: Snapshot?
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)

                if error == nil {
                    if let items = output.coerce(toDescriptorType: typeAEList),
                       items.numberOfItems >= 6 {
                        snapshot = Snapshot(
                            trackName: items.atIndex(1)?.stringValue ?? "",
                            artistName: items.atIndex(2)?.stringValue ?? "",
                            artworkURL: items.atIndex(3)?.stringValue ?? "",
                            isPlaying: items.atIndex(4)?.booleanValue ?? false,
                            position: items.atIndex(5)?.doubleValue ?? 0,
                            duration: (items.atIndex(6)?.doubleValue ?? 0) / 1000.0
                        )
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshInFlight = false
                if let snapshot {
                    self.apply(snapshot)
                } else if let error {
                    print("Could not refresh Spotify state: \(error)")
                }
            }
        }
    }

    private func apply(_ snapshot: Snapshot) {
        trackName = snapshot.trackName
        artistName = snapshot.artistName
        isPlaying = snapshot.isPlaying
        duration = max(0, snapshot.duration)
        position = clampedPosition(snapshot.position)
        lastClockUpdate = Date()

        guard snapshot.artworkURL != currentArtworkURL else { return }
        currentArtworkURL = snapshot.artworkURL
        albumArt = nil
        if !snapshot.artworkURL.isEmpty {
            loadArtwork(from: snapshot.artworkURL)
        }
    }

    private func advanceClock(to now: Date) {
        let elapsed = max(0, now.timeIntervalSince(lastClockUpdate))
        lastClockUpdate = now
        guard isPlaying else { return }
        position = clampedPosition(position + elapsed)
    }

    private func clampedPosition(_ value: Double) -> Double {
        let nonnegative = max(0, value)
        guard duration > 0 else { return nonnegative }
        return min(nonnegative, duration)
    }

    private func loadArtwork(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentArtworkURL == urlString else { return }
                    self.albumArt = image
                }
            }
        }.resume()
    }
}

// MARK: - Spotify Mini Player View
struct SpotifyMiniPlayerCard: View {
    @StateObject private var state = SpotifyState()
    @State private var hoveredButton: String? = nil
    @State private var isHovered = false
    
    let spotifyGreen = Color(red: 0.12, green: 0.84, blue: 0.38)
    
    private var cardWidth: CGFloat {
        DockMonitor.shared.compactOverlayMode ? 180 : 220
    }
    
    private var artSize: CGFloat {
        DockMonitor.shared.compactOverlayMode ? 55 : 70
    }
    
    private var infoWidth: CGFloat {
        DockMonitor.shared.compactOverlayMode ? 100 : 120
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 10) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: artSize, height: artSize)
                    
                    if let art = state.albumArt {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: artSize, height: artSize)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: DockMonitor.shared.compactOverlayMode ? 20 : 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Track info and controls
                VStack(alignment: .leading, spacing: 6) {
                    // Track name
                    Text(state.trackName.isEmpty ? "Not Playing" : state.trackName)
                        .font(.system(size: DockMonitor.shared.compactOverlayMode ? 11 : 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Artist name
                    Text(state.artistName.isEmpty ? "Spotify" : state.artistName)
                        .font(.system(size: DockMonitor.shared.compactOverlayMode ? 9 : 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(spotifyGreen)
                                .frame(width: geo.size.width * progressFraction, height: 3)
                        }
                    }
                    .frame(height: 3)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(state.position))
                            .font(.system(size: DockMonitor.shared.compactOverlayMode ? 8 : 9))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("-\(formatTime(max(0, state.duration - state.position)))")
                            .font(.system(size: DockMonitor.shared.compactOverlayMode ? 8 : 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: infoWidth)
            }
            .padding(DockMonitor.shared.compactOverlayMode ? 8 : 10)
            
            // Playback controls
            HStack(spacing: DockMonitor.shared.compactOverlayMode ? 15 : 20) {
                // Previous
                controlButton(icon: "backward.fill", id: "prev", size: DockMonitor.shared.compactOverlayMode ? 12 : 14) {
                    SpotifyController.previous()
                    refreshAfterDelay()
                }
                
                // Play/Pause
                controlButton(icon: state.isPlaying ? "pause.fill" : "play.fill", id: "play", size: DockMonitor.shared.compactOverlayMode ? 16 : 20) {
                    SpotifyController.playPause()
                    state.setPlayingOptimistically(!state.isPlaying)
                    refreshAfterDelay()
                }
                
                // Next
                controlButton(icon: "forward.fill", id: "next", size: DockMonitor.shared.compactOverlayMode ? 12 : 14) {
                    SpotifyController.next()
                    refreshAfterDelay()
                }
                
                Spacer().frame(width: DockMonitor.shared.compactOverlayMode ? 8 : 10)
                
                // Like
                Button(action: {
                    state.isLiked.toggle()
                    SpotifyController.toggleLike()
                }) {
                    Image(systemName: state.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: DockMonitor.shared.compactOverlayMode ? 12 : 14))
                        .foregroundColor(state.isLiked ? spotifyGreen : (hoveredButton == "like" ? spotifyGreen : .white.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButton == "like" ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: hoveredButton)
                .onHover { h in hoveredButton = h ? "like" : nil }
            }
            .padding(.horizontal, DockMonitor.shared.compactOverlayMode ? 12 : 16)
            .padding(.bottom, DockMonitor.shared.compactOverlayMode ? 8 : 10)
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? spotifyGreen.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { h in isHovered = h }
        .onAppear { state.startUpdating() }
        .onDisappear { state.stopUpdating() }
    }
    
    private func controlButton(icon: String, id: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(hoveredButton == id ? spotifyGreen : .white)
        }
        .buttonStyle(.plain)
        .scaleEffect(hoveredButton == id ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: hoveredButton)
        .onHover { h in hoveredButton = h ? id : nil }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let safeSeconds = max(0, seconds.isFinite ? seconds : 0)
        let mins = Int(safeSeconds) / 60
        let secs = Int(safeSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var progressFraction: CGFloat {
        guard state.duration > 0 else { return 0 }
        return CGFloat(min(max(state.position / state.duration, 0), 1))
    }
    
    private func refreshAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            state.refresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            state.refresh()
        }
    }
}

// MARK: - Spotify Controller (Static Functions)
class SpotifyController {
    
    static func isSpotify(_ appName: String) -> Bool {
        return appName.lowercased() == "spotify"
    }
    
    static func playPause() {
        runAppleScript("tell application \"Spotify\" to playpause")
    }
    
    static func next() {
        runAppleScript("tell application \"Spotify\" to next track")
    }
    
    static func previous() {
        runAppleScript("tell application \"Spotify\" to previous track")
    }
    
    static func toggleLike() {
        // Use CGEvent to send Option+Shift+B directly to Spotify PID
        let runningApps = NSWorkspace.shared.runningApplications
        guard let spotify = runningApps.first(where: { $0.localizedName?.lowercased() == "spotify" }) else {
            return
        }
        
        let spotifyPID = spotify.processIdentifier
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        // Key code for 'B' is 11
        let keyCode: CGKeyCode = 11
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        
        keyDown.flags = [.maskAlternate, .maskShift]
        keyUp.flags = [.maskAlternate, .maskShift]
        
        keyDown.postToPid(spotifyPID)
        keyUp.postToPid(spotifyPID)
    }
    
    private static func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
}
