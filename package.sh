#!/bin/bash
APP_NAME="OTPChecker"
BUNDLE_DIR="${APP_NAME}.app/Contents/MacOS"
RESOURCES_DIR="${APP_NAME}.app/Contents/Resources"
PLIST_FILE="${APP_NAME}.app/Contents/Info.plist"

# 1. Build the binary
swift build -c release

# 2. Create Bundle Structure
mkdir -p "$BUNDLE_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy Binary
cp ".build/release/${APP_NAME}" "$BUNDLE_DIR/"

# 4. Handle Icon (if icon.png exists)
if [ -f "icon.png" ]; then
    echo "Creating AppIcon.icns from icon.png..."
    mkdir -p AppIcon.iconset
    # Generate standard macOS icon sizes
    sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
    sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
    sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png
    
    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "$RESOURCES_DIR/"
    rm -rf AppIcon.iconset AppIcon.icns
    ICON_CONFIG="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
    ICON_CONFIG=""
    echo "No icon.png found. Skipping icon generation."
fi

# 5. Create Info.plist
cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.otpchecker</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    $ICON_CONFIG
</dict>
</plist>
EOF

echo "Bundle created: ${APP_NAME}.app"