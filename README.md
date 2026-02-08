# OTPChecker - macOS Menu Bar App

A lightweight macOS utility that monitors incoming iMessages for One-Time Passwords (OTPs), automatically extracts them, and copies them to your clipboard for easy access.

## Features

- **Menu Bar Access**: Lightweight icon (`key.fill`) resides in your system menu bar.
- **Auto-Extraction**: Automatically detects 4-8 digit codes in new messages using intelligent regex pattern matching.
- **Auto-Copy**: The most recent incoming code is automatically copied to your clipboard.
- **Recent Codes List**: View the last 15 detected codes, including the sender and timestamp.
- **Manual Copy**: Click any code in the menu to copy it. The menu stays open and shows a "Copied!" success message.
- **Privacy Focused**: Operates entirely locally on your machine by reading the system's local iMessage database.

## How It's Made

### Technologies Used
- **Swift 5.9**: High-performance systems language for macOS development.
- **AppKit & Cocoa**: Used for the system-level menu bar integration (`NSStatusBar`) and custom menu views.
- **SQLite.swift**: A type-safe wrapper for SQLite to interact with the local iMessage database.
- **iMessage Database Integration**: Directly queries `~/Library/Messages/chat.db` to detect incoming messages without needing the Messages app to be visible.

### Architecture
1. **`MessageMonitor`**: A background service that polls the `chat.db` every 5 seconds. It uses a readonly connection to ensure stability.
2. **`OTPParser`**: Uses pre-compiled Regular Expressions to identify numeric codes near keywords like "code", "OTP", "verification", etc.
3. **`OTPMenuItemView`**: A custom `NSView` subclass that implements manual click-to-copy logic. By overriding `mouseDown` and not calling `super`, it prevents the menu from closing when an item is selected, allowing the user to see the "Copied!" confirmation.
4. **`AppDelegate`**: Manages the application lifecycle and dynamically builds the menu bar UI.

## Installation & Requirements

### Download Pre-built App
You can download the latest release without building from source:

1. Go to the [Releases page](https://github.com/rajavijayach/OTP-Checker-MacOS-Menu-Bar-App/releases)
2. Download the latest `OTPChecker.app.zip`
3. Extract the ZIP file
4. Move `OTPChecker.app` to your Applications folder
5. Right-click on the app and select "Open" the first time to bypass Gatekeeper

### Permissions
Because Apple protects iMessages, you must grant the application **Full Disk Access**:
1. Open **System Settings**.
2. Go to **Privacy & Security** > **Full Disk Access**.
3. Add/Toggle **OTPChecker.app** (or the Terminal app you are running it from) to the list.

### Building from Source
Alternatively, you can build the app yourself using the provided packaging script:
```bash
./package.sh
open OTPChecker.app
```

## Optimization & Performance
- **Read-Only DB Access**: Ensures no interference with the system Messages app.
- **Low CPU Usage**: Polling logic is extremely efficient and pre-compiled regex minimizes overhead.
- **Accessory App**: The application runs as a background utility with no Dock icon or main window.

## Creating a Release (For Maintainers)

To create a new release with pre-built binaries:

1. Update the version in `package.sh` if needed (currently set to 1.0)
2. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. The GitHub Actions workflow will automatically:
   - Build the macOS app
   - Create a ZIP archive
   - Create a GitHub release with the downloadable app

Users can then download the pre-built app from the Releases page without needing to build from source.
