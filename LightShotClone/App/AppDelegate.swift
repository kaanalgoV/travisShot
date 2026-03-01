import AppKit
import Defaults
import KeyboardShortcuts
import ScreenCaptureKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var editingToolbar: EditingToolbarController?
    private var actionToolbar: ActionToolbarController?
    private var annotationVM = AnnotationViewModel()
    private var annotationWindow: NSWindow?
    private var drawingCanvas: DrawingCanvasNSView?
    private var localKeyMonitor: Any?
    private var settingsWindow: NSWindow?

    /// Set to true only when the user explicitly clicks "Quit"
    var userRequestedQuit = false

    private var screenCapture: CGImage?
    /// Selection rect in SwiftUI coordinates (top-left origin) - used for image cropping
    private var selectionRectForCrop: CGRect?
    /// Selection rect in screen coordinates (bottom-left origin) - used for window positioning
    private var selectionRectScreen: CGRect?
    private var currentScreen: NSScreen?
    /// Saved selection position for "Keep selection position" feature
    private var lastSelectionSwiftUIRect: CGRect?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("TravisShot menu bar app")
        ProcessInfo.processInfo.disableSuddenTermination()
        migrateHotkeysIfNeeded()
        registerHotkeys()
    }

    /// One-time migration: reset global hotkeys so code defaults (Cmd+^) take effect
    private func migrateHotkeysIfNeeded() {
        guard !Defaults[.hotkeyMigrationV2] else { return }
        KeyboardShortcuts.reset(.captureRegion)
        KeyboardShortcuts.reset(.captureFullScreen)
        KeyboardShortcuts.reset(.instantUploadFullScreen)
        Defaults[.hotkeyMigrationV2] = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Hard gate: block ALL termination unless the user explicitly clicked Quit
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userRequestedQuit {
            return .terminateNow
        }
        debugLog("Blocked unexpected termination attempt")
        return .terminateCancel
    }

    private func debugLog(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: "/tmp/travisshot_debug.log") {
                if let fh = FileHandle(forWritingAtPath: "/tmp/travisshot_debug.log") {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: "/tmp/travisshot_debug.log", contents: data)
            }
        }
    }

    // MARK: - Preferences

    func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TravisShot Settings"
        window.minSize = NSSize(width: 480, height: 350)
        window.maxSize = NSSize(width: 700, height: 800)
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    // MARK: - Global Hotkeys

    private func registerHotkeys() {
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak self] in
            self?.startRegionCapture()
        }

        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [weak self] in
            self?.captureAndSaveFullScreen()
        }

        KeyboardShortcuts.onKeyUp(for: .instantUploadFullScreen) { [weak self] in
            self?.captureAndUploadFullScreen()
        }
    }

    // MARK: - Region Capture

    func startRegionCapture() {
        Task { @MainActor in
            do {
                let displays = try await ScreenCaptureService.availableDisplays()
                guard let display = displays.first else { return }
                screenCapture = try await ScreenCaptureService.captureFullScreen(
                    display: display,
                    showCursor: Defaults[.captureCursor]
                )
            } catch {
                showPermissionAlert()
                return
            }

            annotationVM = AnnotationViewModel()
            let overlay = OverlayWindowController()
            overlay.onSelectionComplete = { [weak self] rect, screen in
                self?.onSelectionComplete(swiftUIRect: rect, screen: screen)
            }
            overlay.onCancel = { [weak self] in
                self?.dismissAll()
            }
            overlay.showOverlays(frozenImage: screenCapture)

            if Defaults[.keepSelectionPosition], let lastRect = lastSelectionSwiftUIRect {
                overlay.restoreSelection(lastRect)
            }

            overlayController = overlay
        }
    }

    // MARK: - Selection Complete

    private func onSelectionComplete(swiftUIRect: CGRect, screen: NSScreen) {
        currentScreen = screen

        // Save selection position if "Keep selection position" is enabled
        if Defaults[.keepSelectionPosition] {
            lastSelectionSwiftUIRect = swiftUIRect
        }

        // Store SwiftUI rect (top-left origin) for image cropping
        selectionRectForCrop = swiftUIRect

        // Convert SwiftUI coords (top-left origin) → screen coords (bottom-left origin)
        let screenRect = CGRect(
            x: screen.frame.origin.x + swiftUIRect.origin.x,
            y: screen.frame.origin.y + screen.frame.height - swiftUIRect.origin.y - swiftUIRect.height,
            width: swiftUIRect.width,
            height: swiftUIRect.height
        )
        selectionRectScreen = screenRect

        // Keep overlays for dimming, but stop intercepting mouse events
        overlayController?.makePassthrough()

        showAnnotationCanvas(screenRect: screenRect, screen: screen)

        let editToolbar = EditingToolbarController(annotationVM: annotationVM, isFrozen: screenCapture != nil)
        editToolbar.show(
            near: screenRect,
            onToggleFreeze: { [weak self] in
                guard let self = self else { return }
                if editToolbar.isFrozen {
                    self.overlayController?.unfreeze()
                    editToolbar.setFrozen(false)
                } else {
                    self.captureAndFreeze(editToolbar: editToolbar)
                }
            },
            onClose: { [weak self] in
                self?.dismissAll()
            }
        )
        editingToolbar = editToolbar

        let actToolbar = ActionToolbarController()
        actToolbar.show(
            near: screenRect,
            onUpload: { [weak self] in self?.uploadScreenshot() },
            onSearchSimilar: { [weak self] in self?.searchSimilarImages() },
            onPrint: { [weak self] in self?.printScreenshot() },
            onCopy: { [weak self] in self?.copyToClipboard() },
            onSave: { [weak self] in self?.saveToFile() }
        )
        actionToolbar = actToolbar

        installKeyMonitor()
    }

    private func showAnnotationCanvas(screenRect: CGRect, screen: NSScreen) {
        // Use full screen so the user can draw anywhere (webinar mode)
        let fullScreenRect = screen.frame

        let window = NonDraggableWindow(
            contentRect: fullScreenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false

        let canvas = DrawingCanvasNSView(
            viewModel: annotationVM,
            frame: NSRect(origin: .zero, size: fullScreenRect.size)
        )
        canvas.autoresizingMask = [.width, .height]
        window.contentView = canvas
        drawingCanvas = canvas

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
        annotationWindow = window
    }

    // MARK: - Keyboard Shortcuts During Capture

    private func installKeyMonitor() {
        debugLog("installKeyMonitor called")
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let cmd = event.modifierFlags.contains(.command)
            let char = event.charactersIgnoringModifiers?.lowercased()

            if event.keyCode == 53 { // Escape
                self.dismissAll()
                return nil
            }

            // Cmd+key: action shortcuts (configurable)
            if cmd, let char = char {
                if char == Defaults[.shortcutCopy] { self.copyToClipboard(); return nil }
                if char == Defaults[.shortcutSave] { self.saveToFile(); return nil }
                if char == Defaults[.shortcutUpload] { self.uploadScreenshot(); return nil }
                if char == Defaults[.shortcutPrint] { self.printScreenshot(); return nil }
                if char == Defaults[.shortcutUndo] {
                    self.annotationVM.undo()
                    self.drawingCanvas?.forceRedraw()
                    return nil
                }
            }

            // No modifier: tool shortcuts (configurable)
            // IMPORTANT: Skip when text field is active so typed characters reach the text field
            if !cmd, let char = char, self.drawingCanvas?.isTextFieldActive != true {
                self.debugLog("Key pressed: '\(char)' (no cmd)")
                if char == Defaults[.shortcutSelect] { self.annotationVM.selectTool(.select); return nil }
                if char == Defaults[.shortcutPen] { self.annotationVM.selectTool(.pen); return nil }
                if char == Defaults[.shortcutLine] { self.annotationVM.selectTool(.line); return nil }
                if char == Defaults[.shortcutArrow] { self.annotationVM.selectTool(.arrow); return nil }
                if char == Defaults[.shortcutRectangle] { self.annotationVM.selectTool(.rectangle); return nil }
                if char == Defaults[.shortcutText] { self.annotationVM.selectTool(.text); return nil }
                if char == Defaults[.shortcutMarker] { self.annotationVM.selectTool(.marker); return nil }
                if char == Defaults[.shortcutFreeze] {
                    if let toolbar = self.editingToolbar {
                        if toolbar.isFrozen {
                            self.overlayController?.unfreeze()
                            toolbar.setFrozen(false)
                        } else {
                            self.captureAndFreeze(editToolbar: toolbar)
                        }
                    }
                    return nil
                }
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    // MARK: - Freeze

    private func captureAndFreeze(editToolbar: EditingToolbarController) {
        Task { @MainActor in
            do {
                let displays = try await ScreenCaptureService.availableDisplays()
                guard let display = displays.first else { return }
                let newCapture = try await ScreenCaptureService.captureFullScreen(
                    display: display,
                    showCursor: Defaults[.captureCursor]
                )
                self.screenCapture = newCapture
                self.overlayController?.freeze(newImage: newCapture)
                editToolbar.setFrozen(true)
            } catch {
                debugLog("Re-freeze capture failed: \(error)")
            }
        }
    }

    // MARK: - Actions

    private func getFinalImage() -> NSImage? {
        // Use SwiftUI rect (top-left origin) for cropping - matches CGImage coordinate system
        guard let capture = screenCapture, let rect = selectionRectForCrop else { return nil }

        // Compute actual scale from CGImage vs screen dimensions (handles both point/pixel SCDisplay)
        let screenWidth = currentScreen?.frame.width ?? 1440
        let scale = CGFloat(capture.width) / screenWidth
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped = capture.cropping(to: scaledRect) else { return nil }

        let finalCG = annotationVM.renderAnnotations(onto: cropped, selectionRect: rect, scale: scale) ?? cropped

        return NSImage(cgImage: finalCG, size: NSSize(width: rect.width, height: rect.height))
    }

    private func copyToClipboard() {
        guard let image = getFinalImage() else { return }
        ClipboardService.copy(image)
        showSuccessFeedback("Copied to clipboard")
        dismissAll()
    }

    private func saveToFile() {
        guard let image = getFinalImage() else { return }
        dismissAll() // Dismiss overlays first so save dialog is not hidden behind them
        Task { @MainActor in
            let _ = await FileSaveService.saveWithDialog(image)
            showSuccessFeedback("Screenshot saved")
        }
    }

    private func uploadScreenshot() {
        guard let image = getFinalImage() else { return }
        Task {
            do {
                let link = try await ImageUploadService.uploadToImgur(image)
                await MainActor.run {
                    if Defaults[.autoCopyLinkAfterUpload] {
                        ClipboardService.copyText(link)
                    }
                    showSuccessFeedback("Screenshot uploaded")
                    dismissAll()
                }
            } catch {
                await MainActor.run {
                    dismissAll()
                    showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Upload Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "TravisShot needs screen recording permission to capture screenshots. Please grant access in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showSuccessFeedback(_ message: String) {
        guard Defaults[.showNotifications] else { return }
        NSSound.beep()
    }

    private func searchSimilarImages() {
        guard let image = getFinalImage() else { return }
        Task {
            await ImageUploadService.searchSimilarImages(image: image)
            await MainActor.run { dismissAll() }
        }
    }

    private func printScreenshot() {
        guard let image = getFinalImage() else { return }
        Task { @MainActor in
            PrintService.printImage(image)
            dismissAll()
        }
    }

    // MARK: - Full Screen Capture Shortcuts

    private func captureAndSaveFullScreen() {
        Task { @MainActor in
            do {
                let displays = try await ScreenCaptureService.availableDisplays()
                guard let display = displays.first else { return }
                let capture = try await ScreenCaptureService.captureFullScreen(
                    display: display,
                    showCursor: Defaults[.captureCursor]
                )
                let image = NSImage(cgImage: capture, size: NSSize(width: capture.width, height: capture.height))
                let _ = FileSaveService.save(image, to: quickSaveURL(ext: "png"))
                showSuccessFeedback("Screenshot saved")
            } catch {
                showPermissionAlert()
            }
        }
    }

    private func captureAndUploadFullScreen() {
        Task {
            do {
                let displays = try await ScreenCaptureService.availableDisplays()
                guard let display = displays.first else { return }
                let capture = try await ScreenCaptureService.captureFullScreen(
                    display: display,
                    showCursor: Defaults[.captureCursor]
                )
                let image = NSImage(cgImage: capture, size: NSSize(width: capture.width, height: capture.height))
                let link = try await ImageUploadService.uploadToImgur(image)
                await MainActor.run {
                    if Defaults[.autoCopyLinkAfterUpload] {
                        ClipboardService.copyText(link)
                    }
                    showSuccessFeedback("Screenshot uploaded")
                }
            } catch {
                await MainActor.run {
                    showPermissionAlert()
                }
            }
        }
    }

    private func quickSaveURL(ext: String) -> URL {
        let quickDir = Defaults[.quickSaveDirectory]
        let directory: URL
        if !quickDir.isEmpty {
            directory = URL(fileURLWithPath: quickDir)
        } else {
            directory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return directory.appendingPathComponent("Screenshot \(df.string(from: Date())).\(ext)")
    }

    // MARK: - Dismiss

    private func dismissAll() {
        debugLog("dismissAll called")
        removeKeyMonitor()
        drawingCanvas?.commitTextField()
        drawingCanvas = nil
        overlayController?.dismissOverlays()
        overlayController = nil
        editingToolbar?.dismiss()
        editingToolbar = nil
        actionToolbar?.dismiss()
        actionToolbar = nil
        annotationWindow?.close()
        annotationWindow = nil
        screenCapture = nil
        selectionRectForCrop = nil
        selectionRectScreen = nil
        currentScreen = nil
    }
}
