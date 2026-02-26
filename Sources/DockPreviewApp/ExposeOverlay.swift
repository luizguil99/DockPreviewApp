import SwiftUI
import AppKit

// MARK: - Individual window tile

struct ExposeWindowTile: View {
    let window: AppWindow
    let previewSize: CGSize
    let tileIndex: Int
    let onSelect: () -> Void

    @State private var appeared = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.10))

                if let image = window.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: previewSize.width, height: previewSize.height)
                } else {
                    Image(systemName: window.isMinimized
                          ? "arrow.down.right.and.arrow.up.left"
                          : "macwindow")
                        .font(.system(size: min(previewSize.width, previewSize.height) * 0.25))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: previewSize.width, height: previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isHovered      ? Color.blue
                            : window.isFocused  ? Color.white.opacity(0.9)
                            : Color.white.opacity(0.18),
                        lineWidth: isHovered ? 3 : (window.isFocused ? 2 : 1)
                    )
            )
            .shadow(
                color: isHovered      ? .blue.opacity(0.55)
                    : window.isFocused  ? .white.opacity(0.25)
                    : .black.opacity(0.5),
                radius: isHovered ? 18 : (window.isFocused ? 12 : 8)
            )

            // Title
            Text(window.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.8))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: previewSize.width)
                .shadow(color: .black.opacity(0.9), radius: 2)
        }
        .scaleEffect(appeared ? (isHovered ? 1.06 : 1.0) : 0.82)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.28, dampingFraction: 0.78)
                .delay(Double(tileIndex) * 0.03),
            value: appeared
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .onAppear { appeared = true }
    }
}

// MARK: - Grid layout

struct ExposeGridLayout: View {
    let windows: [AppWindow]
    let availableSize: CGSize
    let onSelect: (AppWindow) -> Void

    private let spacing: CGFloat = 22
    private let titleHeight: CGFloat = 30

    private struct CellInfo: Identifiable {
        let id: Int
        let window: AppWindow
        let previewWidth: CGFloat
        let previewHeight: CGFloat
        let centerX: CGFloat
        let centerY: CGFloat
    }

    private func buildLayout() -> [CellInfo] {
        let n = windows.count
        guard n > 0, availableSize.width > 0, availableSize.height > 0 else { return [] }

        let W = availableSize.width
        let H = availableSize.height
        let s = spacing
        let th = titleHeight

        // Find cols that maximises cell area
        var bestCols = 1
        var bestArea: CGFloat = 0
        for c in 1...n {
            let r = Int(ceil(Double(n) / Double(c)))
            let cw = (W - s * CGFloat(c + 1)) / CGFloat(c)
            let ch = (H - s * CGFloat(r + 1)) / CGFloat(r)
            let area = cw * max(0, ch - th)
            if area > bestArea && cw > 60 && ch > 60 {
                bestArea = area
                bestCols = c
            }
        }

        let cols = bestCols
        let rows = Int(ceil(Double(n) / Double(cols)))
        let cellW = (W - s * CGFloat(cols + 1)) / CGFloat(cols)
        let cellH = (H - s * CGFloat(rows + 1)) / CGFloat(rows)
        let previewAreaH = max(50, cellH - th)

        var result: [CellInfo] = []

        for (i, window) in windows.enumerated() {
            let col = i % cols
            let row = i / cols

            // Center the last (possibly incomplete) row
            let isLastRow = row == rows - 1
            let lastRowCount = n - (rows - 1) * cols
            let lastRowOffset: CGFloat = isLastRow
                ? (CGFloat(cols - lastRowCount) * (cellW + s)) / 2.0
                : 0

            let cellX = s + CGFloat(col) * (cellW + s) + lastRowOffset
            let cellY = s + CGFloat(row) * (cellH + s)
            let cellCenterX = cellX + cellW / 2
            let cellCenterY = cellY + cellH / 2

            // Scale preview to fit, preserving aspect ratio
            let winW = window.bounds.width > 1
                ? window.bounds.width
                : (window.image?.size.width ?? 1280)
            let winH = window.bounds.height > 1
                ? window.bounds.height
                : (window.image?.size.height ?? 800)
            let aspect = winW / winH
            let areaAspect = cellW / previewAreaH

            let pw: CGFloat
            let ph: CGFloat
            if aspect > areaAspect {
                pw = cellW
                ph = cellW / aspect
            } else {
                ph = previewAreaH
                pw = previewAreaH * aspect
            }

            result.append(CellInfo(
                id: i,
                window: window,
                previewWidth: pw,
                previewHeight: ph,
                centerX: cellCenterX,
                centerY: cellCenterY
            ))
        }

        return result
    }

    var body: some View {
        let cells = buildLayout()

        ZStack {
            ForEach(cells) { cell in
                ExposeWindowTile(
                    window: cell.window,
                    previewSize: CGSize(width: cell.previewWidth, height: cell.previewHeight),
                    tileIndex: cell.id,
                    onSelect: { onSelect(cell.window) }
                )
                .frame(
                    width: cell.previewWidth,
                    height: cell.previewHeight + titleHeight
                )
                .position(x: cell.centerX, y: cell.centerY)
            }
        }
        .frame(width: availableSize.width, height: availableSize.height)
    }
}

// MARK: - Root Exposé view

struct ExposeOverlayView: View {
    @ObservedObject var windowsModel: WindowsModel
    let appIcon: NSImage?
    let onSelect: (AppWindow) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    // Height reserved for the app header bar
    private let headerHeight: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Dark backdrop – tap on empty space dismisses
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        if let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                        }
                        Text(windowsModel.appName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)

                        Spacer()

                        // ESC hint
                        Text("esc")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                    .frame(height: headerHeight)

                    // Window grid
                    if windowsModel.windows.isEmpty {
                        Spacer()
                        Text("No open windows")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    } else {
                        ExposeGridLayout(
                            windows: windowsModel.windows,
                            availableSize: CGSize(
                                width: geo.size.width - 32,
                                height: geo.size.height - headerHeight - 16
                            ),
                            onSelect: { onSelect($0) }
                        )
                        .frame(
                            width: geo.size.width - 32,
                            height: geo.size.height - headerHeight - 16
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .allowsHitTesting(true)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                appeared = true
            }
        }
    }
}
