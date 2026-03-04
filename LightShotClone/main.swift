import AppKit

// Pure AppKit lifecycle — no SwiftUI App wrapper needed.
// The status bar menu and settings window are managed by AppDelegate.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
