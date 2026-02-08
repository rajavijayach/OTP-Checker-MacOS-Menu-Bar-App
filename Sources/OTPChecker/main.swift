import SwiftUI
import SQLite
import Foundation
import AppKit

// MARK: - Data Models
/// Represents an OTP message extracted from the iMessage database.
struct Message: Identifiable, Hashable {
    let id: Int64
    let sender: String
    let content: String
    let date: Date
    let otp: String
}

// MARK: - OTP Parser Logic
/// Utility to extract 4-8 digit codes from text using regex patterns.
struct OTPParser {
    // Pre-compiled regex for better performance during polling
    private static let strongRegex = try? NSRegularExpression(pattern: #"(?i)(?:code|otp|pin|verification|password|login|passwd).{0,20}(\b\d{4,8}\b)|(\b\d{4,8}\b).{0,20}(?:code|otp|pin|verification|password|login|passwd)"#)
    private static let weakRegex = try? NSRegularExpression(pattern: #"\b\d{4,8}\b"#)

    static func extractOTP(from text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        // Strategy 1: Look for keywords near digits (Strong Signal)
        if let match = strongRegex?.firstMatch(in: text, options: [], range: range) {
            if let r1 = Range(match.range(at: 1), in: text) { return String(text[r1]) }
            if let r2 = Range(match.range(at: 2), in: text) { return String(text[r2]) }
        }
        
        // Strategy 2: Standalone digits for short messages (Weak Signal)
        if text.count < 60, let match = weakRegex?.firstMatch(in: text, options: [], range: range) {
            if let r = Range(match.range, in: text) { return String(text[r]) }
        }
        
        return nil
    }
}

// MARK: - Message Monitor
/// Watches the macOS iMessage SQLite database for new messages.
class MessageMonitor: ObservableObject {
    @Published var recentMessages: [Message] = []
    @Published var status: String = "Initializing..."
    @Published var hasAccess: Bool = false
    
    private var lastCheckedId: Int64 = 0
    private var timer: Timer?
    private let dbPath: String
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.dbPath = home.appendingPathComponent("Library/Messages/chat.db").path
    }
    
    func start() {
        checkDatabase()
        // Poll every 5 seconds for new messages
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkDatabase()
        }
    }
    
    func checkDatabase() {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            DispatchQueue.main.async { self.status = "chat.db not found" }
            return
        }
        
        do {
            // Open connection in readonly mode to avoid database locks
            let db = try Connection(dbPath, readonly: true)
            
            // SQL Query to join message and handle tables
            // message.date is nanoseconds since 2001-01-01 (Apple/Cocoa Reference Date)
            let query = """
                SELECT message.ROWID, message.text, message.date, handle.id 
                FROM message 
                LEFT JOIN handle ON message.handle_id = handle.ROWID 
                WHERE message.text IS NOT NULL 
                ORDER BY message.date DESC LIMIT 15
            """
            
            var extracted: [Message] = []
            let statement = try db.prepare(query)
            
            for row in statement {
                guard let rowId = row[0] as? Int64, 
                      let text = row[1] as? String, 
                      let dateNano = row[2] as? Int64 else { continue }
                
                let sender = (row[3] as? String) ?? "Unknown"
                let date = Date(timeIntervalSinceReferenceDate: Double(dateNano) / 1_000_000_000)
                
                if let otp = OTPParser.extractOTP(from: text) {
                    extracted.append(Message(id: rowId, sender: sender, content: text, date: date, otp: otp))
                }
            }
            
            DispatchQueue.main.async {
                self.hasAccess = true
                self.status = "Scanning..."
                
                // Automatic clipboard sync for brand-new incoming codes
                if let newest = extracted.first {
                    if self.lastCheckedId != 0 && newest.id > self.lastCheckedId {
                        self.copyToClipboard(newest.otp)
                    }
                    self.lastCheckedId = max(self.lastCheckedId, newest.id)
                }
                self.recentMessages = extracted
            }
        } catch {
            DispatchQueue.main.async {
                self.hasAccess = false
                self.status = "Access Denied"
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Custom Menu Item View
/// A custom view for menu items that allows clicking without closing the menu.
class OTPMenuItemView: NSView {
    let otp: String
    let senderName: String
    let timeStr: String
    let onCopy: (String) -> Void
    
    var isCopied: Bool = false { didSet { updateUI() } }
    var isHighlighted: Bool = false { 
        didSet { 
            updateUI()
            needsDisplay = true // Trigger draw() override
        }
    }
    
    private let textField = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private var trackingArea: NSTrackingArea?
    
    init(otp: String, sender: String, time: String, onCopy: @escaping (String) -> Void) {
        self.otp = otp
        self.senderName = sender
        self.timeStr = time
        self.onCopy = onCopy
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textField)
        addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        updateUI()
    }
    
    /// Draws the blue background highlight when the user hovers over the item.
    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.set()
            dirtyRect.fill()
        }
    }
    
    private func updateUI() {
        if isHighlighted {
            textField.textColor = .alternateSelectedControlTextColor
            iconView.contentTintColor = .alternateSelectedControlTextColor
        } else {
            textField.textColor = .labelColor
            iconView.contentTintColor = .secondaryLabelColor
        }
        
        if isCopied {
            textField.stringValue = "✅ \(otp) Copied!"
            if !isHighlighted { textField.textColor = .systemGreen }
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        } else {
            textField.stringValue = "\(otp) (\(senderName)) - \(timeStr)"
            iconView.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        }
    }
    
    // Tracking area ensures mouseEntered/Exited events are fired
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent) { isHighlighted = false }
    
    override func mouseDown(with event: NSEvent) {
        onCopy(otp)
        isCopied = true
        // Revert "Copied" text after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isCopied = false
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    let monitor = MessageMonitor()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Menu Bar Icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "OTP Checker")
        }
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        
        // Ensure app doesn't show in Dock
        NSApp.setActivationPolicy(.accessory)
        monitor.start()
    }
    
    /// Dynamically builds the menu every time it is opened.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let header = NSMenuItem(title: "Recent OTPs", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())
        
        if !monitor.hasAccess {
            menu.addItem(NSMenuItem(title: "⚠️ \(monitor.status)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Please Grant Full Disk Access", action: nil, keyEquivalent: ""))
        } else if monitor.recentMessages.isEmpty {
            menu.addItem(NSMenuItem(title: "No recent codes found", action: nil, keyEquivalent: ""))
        } else {
            for msg in monitor.recentMessages {
                let item = NSMenuItem()
                let itemView = OTPMenuItemView(otp: msg.otp, sender: msg.sender, time: dateFormatter.string(from: msg.date)) { [weak self] otp in
                    self?.monitor.copyToClipboard(otp)
                }
                item.view = itemView
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Messages", action: #selector(refreshDB), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    
    @objc func refreshDB() {
        monitor.checkDatabase()
    }
}

// MARK: - Main Loop
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()