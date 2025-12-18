#!/bin/bash

# Build the app
echo "🔨 Building DockPreviewApp..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

# Generate icon if it doesn't exist
if [ ! -f "AppIcon.icns" ]; then
    echo "🎨 Generating app icon..."
    swift generate-icon.swift
fi

# Create app bundle structure
APP_NAME="DockPreviewApp"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating app bundle..."

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Copy icon if exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/"
    echo "✓ Icon added to bundle"
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DockPreviewApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.dockpreview.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DockPreview</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>DockPreview needs Apple Events to open new windows in apps.</string>
</dict>
</plist>
EOF

echo "✅ App bundle created: $APP_BUNDLE"
echo ""
echo "📍 To install:"
echo "   1. Move $APP_BUNDLE to /Applications"
echo "   2. Or double-click to run from here"
echo ""
echo "🚀 To start at login:"
echo "   System Settings → General → Login Items → Add DockPreviewApp"
echo ""
echo "⚠️  First run: Grant Accessibility permissions when prompted"

# Open the folder
open .
