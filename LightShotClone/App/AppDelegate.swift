import AppKit
import KeyboardShortcuts
import ScreenCaptureKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var editingToolbar: EditingToolbarController?
    private var actionToolbar: ActionToolbarController?
    private var annotationVM = AnnotationViewModel()
    private var annotationWindow: NSWindow?
    private var localKeyMonitor: Any?

    private var screenCapture: CGImage?
    private var currentSelectionRect: CGRect?
    private var currentScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotkeys()
        checkPermissions()
    }

    // MARK: - Permissions

    private func checkPermissions() {
        if !PermissionManager.hasScreenRecordingPermission {
            PermissionManager.requestScreenRecordingPermission()
        }
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
            guard let displays = try? await ScreenCaptureService.availableDisplays(),
                  let display = displays.first else { return }
            screenCapture = try? await ScreenCaptureService.captureFullScreen(display: display)

            annotationVM = AnnotationViewModel()
            let overlay = OverlayWindowController()
            overlay.onSelectionComplete = { [weak self] rect, screen in
                self?.onSelectionComplete(rect: rect, screen: screen)
            }
            overlay.onCancel = { [weak self] in
                self?.dismissAll()
            }
            overlay.showOverlays()
            overlayController = overlay
        }
    }

    // MARK: - Selection Complete

    private func onSelectionComplete(rect: CGRect, screen: NSScreen) {
        currentSelectionRect = rect
        currentScreen = screen

        showAnnotationCanvas(rect: rect, screen: screen)

        let editToolbar = EditingToolbarController(annotationVM: annotationVM)
        editToolbar.show(near: rect, onClose: { [weak self] in
            self?.dismissAll()
        })
        editingToolbar = editToolbar

        let actToolbar = ActionToolbarController()
        actToolbar.show(
            near: rect,
            onUpload: { [weak self] in self?.uploadScreenshot() },
            onSearchSimilar: { [weak self] in self?.searchSimilarImages() },
            onPrint: { [weak self] in self?.printScreenshot() },
            onCopy: { [weak self] in self?.copyToClipboard() },
            onSave: { [weak self] in self?.saveToFile() }
        )
        actionToolbar = actToolbar

        installKeyMonitor()
    }

    private func showAnnotationCanvas(rect: CGRect, screen: NSScreen) {
        let window = NSWindow(
            contentRect: rect,
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

        let canvasView = AnnotationCanvasView(
            viewModel: annotationVM,
            canvasSize: rect.size
        )
        window.contentView = NSHostingView(rootView: canvasView)
        window.makeKeyAndOrderFront(nil)
        annotationWindow = window
    }

    // MARK: - Keyboard Shortcuts During Capture

    private func installKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let cmd = event.modifierFlags.contains(.command)

            if event.keyCode == 53 { // Escape
                self.dismissAll()
                return nil
            }

            if cmd {
                switch event.charactersIgnoringModifiers {
                case "c":
                    self.copyToClipboard()
                    return nil
                case "s":
                    self.saveToFile()
                    return nil
                case "d":
                    self.uploadScreenshot()
                    return nil
                case "p":
                    self.printScreenshot()
                    return nil
                case "z":
                    self.annotationVM.undo()
                    return nil
                case "a":
                    if let screen = self.currentScreen {
                        self.currentSelectionRect = screen.frame
                    }
                    return nil
                default: break
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

    // MARK: - Actions

    private func getFinalImage() -> NSImage? {
        guard let capture = screenCapture, let rect = currentSelectionRect else { return nil }

        let scale = currentScreen?.backingScaleFactor ?? 2.0
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped = capture.cropping(to: scaledRect) else { return nil }

        let finalCG = annotationVM.renderAnnotations(onto: cropped, selectionRect: rect) ?? cropped

        return NSImage(cgImage: finalCG, size: NSSize(width: rect.width, height: rect.height))
    }

    private func copyToClipboard() {
        guard let image = getFinalImage() else { return }
        ClipboardService.copy(image)
        dismissAll()
    }

    private func saveToFile() {
        guard let image = getFinalImage() else { return }
        Task { @MainActor in
            let _ = await FileSaveService.saveWithDialog(image)
            dismissAll()
        }
    }

    private func uploadScreenshot() {
        guard let image = getFinalImage() else { return }
        Task {
            do {
                let link = try await ImageUploadService.uploadToImgur(image)
                await MainActor.run {
                    ClipboardService.copyText(link)
                    dismissAll()
                }
            } catch {
                // silently fail for now
                await MainActor.run { dismissAll() }
            }
        }
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
            guard let displays = try? await ScreenCaptureService.availableDisplays(),
                  let display = displays.first,
                  let capture = try? await ScreenCaptureService.captureFullScreen(display: display) else { return }
            let image = NSImage(cgImage: capture, size: NSSize(width: capture.width, height: capture.height))
            let _ = FileSaveService.save(image, to: desktopURL(ext: "png"))
        }
    }

    private func captureAndUploadFullScreen() {
        Task {
            guard let displays = try? await ScreenCaptureService.availableDisplays(),
                  let display = displays.first,
                  let capture = try? await ScreenCaptureService.captureFullScreen(display: display) else { return }
            let image = NSImage(cgImage: capture, size: NSSize(width: capture.width, height: capture.height))
            if let link = try? await ImageUploadService.uploadToImgur(image) {
                await MainActor.run {
                    ClipboardService.copyText(link)
                }
            }
        }
    }

    private func desktopURL(ext: String) -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return desktop.appendingPathComponent("Screenshot \(df.string(from: Date())).\(ext)")
    }

    // MARK: - Dismiss

    private func dismissAll() {
        removeKeyMonitor()
        overlayController?.dismissOverlays()
        overlayController = nil
        editingToolbar?.dismiss()
        editingToolbar = nil
        actionToolbar?.dismiss()
        actionToolbar = nil
        annotationWindow?.close()
        annotationWindow = nil
        screenCapture = nil
        currentSelectionRect = nil
        currentScreen = nil
    }
}
