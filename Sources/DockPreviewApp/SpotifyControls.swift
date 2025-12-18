import SwiftUI
import AppKit

// MARK: - Spotify Data Model
class SpotifyState: ObservableObject {
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var albumArt: NSImage?
    @Published var isPlaying: Bool = false
    @Published var position: Double = 0  // in seconds
    @Published var duration: Double = 0  // in seconds
    @Published var isLiked: Bool = false
    
    func refresh() {
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
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                
                if error == nil {
                    DispatchQueue.main.async {
                        // Parse the output
                        if let items = output.coerce(toDescriptorType: typeAEList) {
                            let count = items.numberOfItems
                            if count >= 6 {
                                self.trackName = items.atIndex(1)?.stringValue ?? ""
                                self.artistName = items.atIndex(2)?.stringValue ?? ""
                                let artworkUrl = items.atIndex(3)?.stringValue ?? ""
                                self.isPlaying = items.atIndex(4)?.booleanValue ?? false
                                self.position = Double(items.atIndex(5)?.int32Value ?? 0)
                                self.duration = Double(items.atIndex(6)?.int32Value ?? 0) / 1000.0
                                
                                // Load artwork
                                if !artworkUrl.isEmpty {
                                    self.loadArtwork(from: artworkUrl)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadArtwork(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 10) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 70, height: 70)
                    
                    if let art = state.albumArt {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Track info and controls
                VStack(alignment: .leading, spacing: 6) {
                    // Track name
                    Text(state.trackName.isEmpty ? "Not Playing" : state.trackName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Artist name
                    Text(state.artistName.isEmpty ? "Spotify" : state.artistName)
                        .font(.system(size: 10))
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
                                .frame(width: state.duration > 0 ? geo.size.width * CGFloat(state.position / state.duration) : 0, height: 3)
                        }
                    }
                    .frame(height: 3)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(state.position))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("-\(formatTime(state.duration - state.position))")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: 120)
            }
            .padding(10)
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous
                controlButton(icon: "backward.fill", id: "prev", size: 14) {
                    SpotifyController.previous()
                    refreshAfterDelay()
                }
                
                // Play/Pause
                controlButton(icon: state.isPlaying ? "pause.fill" : "play.fill", id: "play", size: 20) {
                    SpotifyController.playPause()
                    state.isPlaying.toggle()
                }
                
                // Next
                controlButton(icon: "forward.fill", id: "next", size: 14) {
                    SpotifyController.next()
                    refreshAfterDelay()
                }
                
                Spacer().frame(width: 10)
                
                // Like
                Button(action: {
                    state.isLiked.toggle()
                    SpotifyController.toggleLike()
                }) {
                    Image(systemName: state.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(state.isLiked ? spotifyGreen : (hoveredButton == "like" ? spotifyGreen : .white.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButton == "like" ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: hoveredButton)
                .onHover { h in hoveredButton = h ? "like" : nil }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(width: 220)
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
        .onAppear {
            state.refresh()
            // Auto refresh every 1 second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if state.isPlaying {
                    state.position += 1
                }
            }
        }
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
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func refreshAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
