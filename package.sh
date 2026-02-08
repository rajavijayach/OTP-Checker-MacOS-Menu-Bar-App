#!/bin/bash
APP_NAME="OTPChecker"
BUNDLE_DIR="${APP_NAME}.app/Contents/MacOS"
PLIST_FILE="${APP_NAME}.app/Contents/Info.plist"

# 1. Build
swift build -c release

# 2. Create Structure
mkdir -p "$BUNDLE_DIR"

# 3. Copy Binary
cp ".build/release/${APP_NAME}" "$BUNDLE_DIR/"

# 4. Create Info.plist
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
</dict>
</plist>
EOF

echo "Bundle created: ${APP_NAME}.app"
