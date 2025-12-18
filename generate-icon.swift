#!/usr/bin/env swift

import AppKit
import Foundation

// Icon sizes needed for .icns
let sizes: [(size: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16"),
    (16, 2, "icon_16x16@2x"),
    (32, 1, "icon_32x32"),
    (32, 2, "icon_32x32@2x"),
    (128, 1, "icon_128x128"),
    (128, 2, "icon_128x128@2x"),
    (256, 1, "icon_256x256"),
    (256, 2, "icon_256x256@2x"),
    (512, 1, "icon_512x512"),
    (512, 2, "icon_512x512@2x")
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let context = NSGraphicsContext.current!.cgContext
    
    // Background - rounded rectangle with gradient
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let path = CGPath(roundedRect: rect.insetBy(dx: size * 0.02, dy: size * 0.02), 
                      cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Gradient background (dark blue to purple)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.1, green: 0.1, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.15, green: 0.1, blue: 0.35, alpha: 1.0),
        CGColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 1.0)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.5, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(gradient, 
                                   start: CGPoint(x: 0, y: size), 
                                   end: CGPoint(x: size, y: 0), 
                                   options: [])
        context.restoreGState()
    }
    
    // Add subtle border
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.1))
    context.setLineWidth(size * 0.01)
    context.addPath(path)
    context.strokePath()
    
    // Draw stacked windows icon
    let windowWidth = size * 0.45
    let windowHeight = size * 0.35
    let centerX = size / 2
    let centerY = size / 2
    
    // Back window (offset)
    let backWindow = CGRect(x: centerX - windowWidth/2 + size * 0.08, 
                            y: centerY - windowHeight/2 + size * 0.08, 
                            width: windowWidth, height: windowHeight)
    drawWindow(context: context, rect: backWindow, alpha: 0.4, size: size)
    
    // Middle window (slight offset)
    let middleWindow = CGRect(x: centerX - windowWidth/2 + size * 0.04, 
                              y: centerY - windowHeight/2 + size * 0.04, 
                              width: windowWidth, height: windowHeight)
    drawWindow(context: context, rect: middleWindow, alpha: 0.6, size: size)
    
    // Front window
    let frontWindow = CGRect(x: centerX - windowWidth/2, 
                             y: centerY - windowHeight/2, 
                             width: windowWidth, height: windowHeight)
    drawWindow(context: context, rect: frontWindow, alpha: 1.0, size: size)
    
    // Draw preview indicator (eye icon) at bottom
    let eyeSize = size * 0.15
    let eyeY = size * 0.18
    drawEye(context: context, centerX: centerX, centerY: eyeY, size: eyeSize)
    
    image.unlockFocus()
    
    return image
}

func drawWindow(context: CGContext, rect: CGRect, alpha: CGFloat, size: CGFloat) {
    let cornerRadius = size * 0.03
    let windowPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Window background
    context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.3, alpha: alpha))
    context.addPath(windowPath)
    context.fillPath()
    
    // Window border (glowing effect)
    context.setStrokeColor(CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: alpha))
    context.setLineWidth(size * 0.015)
    context.addPath(windowPath)
    context.strokePath()
    
    // Title bar
    let titleBarHeight = size * 0.06
    let titleBar = CGRect(x: rect.minX, y: rect.maxY - titleBarHeight, 
                          width: rect.width, height: titleBarHeight)
    let titlePath = CGPath(roundedRect: titleBar, 
                           cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.9, alpha: alpha * 0.5))
    context.addPath(titlePath)
    context.fillPath()
    
    // Traffic light dots
    let dotRadius = size * 0.012
    let dotY = rect.maxY - titleBarHeight/2
    let dotStartX = rect.minX + size * 0.04
    let dotSpacing = size * 0.03
    
    let dotColors: [(CGFloat, CGFloat, CGFloat)] = [
        (1.0, 0.4, 0.4),  // Red
        (1.0, 0.8, 0.3),  // Yellow
        (0.4, 0.9, 0.4)   // Green
    ]
    
    for (i, color) in dotColors.enumerated() {
        let dotX = dotStartX + CGFloat(i) * dotSpacing
        context.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha))
        context.fillEllipse(in: CGRect(x: dotX - dotRadius, y: dotY - dotRadius, 
                                       width: dotRadius * 2, height: dotRadius * 2))
    }
}

func drawEye(context: CGContext, centerX: CGFloat, centerY: CGFloat, size: CGFloat) {
    // Eye outline
    let eyeWidth = size
    let eyeHeight = size * 0.5
    
    context.saveGState()
    
    // Draw eye shape (almond)
    context.move(to: CGPoint(x: centerX - eyeWidth/2, y: centerY))
    context.addQuadCurve(to: CGPoint(x: centerX + eyeWidth/2, y: centerY), 
                         control: CGPoint(x: centerX, y: centerY + eyeHeight))
    context.addQuadCurve(to: CGPoint(x: centerX - eyeWidth/2, y: centerY), 
                         control: CGPoint(x: centerX, y: centerY - eyeHeight))
    
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    context.fillPath()
    
    // Pupil
    let pupilRadius = size * 0.2
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: centerX - pupilRadius, y: centerY - pupilRadius, 
                                   width: pupilRadius * 2, height: pupilRadius * 2))
    
    // Pupil highlight
    let highlightRadius = size * 0.08
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.8))
    context.fillEllipse(in: CGRect(x: centerX - pupilRadius * 0.3 - highlightRadius/2, 
                                   y: centerY + pupilRadius * 0.2 - highlightRadius/2, 
                                   width: highlightRadius, height: highlightRadius))
    
    context.restoreGState()
}

func savePNG(image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write PNG: \(error)")
    }
}

// Main
print("🎨 Generating DockPreview icon...")

// Create iconset directory
let iconsetPath = "AppIcon.iconset"
let fileManager = FileManager.default

// Remove old iconset if exists
try? fileManager.removeItem(atPath: iconsetPath)

// Create iconset directory
try! fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate each size
for sizeInfo in sizes {
    let pixelSize = sizeInfo.size * sizeInfo.scale
    let image = drawIcon(size: CGFloat(pixelSize))
    let filename = "\(iconsetPath)/\(sizeInfo.name).png"
    savePNG(image: image, to: filename)
    print("  ✓ Generated \(sizeInfo.name).png (\(pixelSize)x\(pixelSize))")
}

print("📦 Converting to .icns...")

// Convert to icns using iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "AppIcon.icns"]

do {
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus == 0 {
        print("✅ Icon created: AppIcon.icns")
        
        // Clean up iconset
        try? fileManager.removeItem(atPath: iconsetPath)
    } else {
        print("❌ iconutil failed with status \(process.terminationStatus)")
    }
} catch {
    print("❌ Failed to run iconutil: \(error)")
}
