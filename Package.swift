// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockPreviewApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DockPreviewApp", targets: ["DockPreviewApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DockPreviewApp",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Cocoa"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)

