# TravisShot Remaining Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire up all 5 non-functional settings, add user-facing error handling, polish text annotations, cap undo memory, and remove dead code — making TravisShot fully production-ready.

**Architecture:** Each fix is self-contained. Settings changes read from `Defaults[.key]` at point-of-use. Notifications use `NSSound.beep()` + brief `NSAlert` (UserNotifications requires a proper bundle). Dead code removal is last to avoid merge conflicts.

**Tech Stack:** Swift 5.9+, macOS 14+, AppKit, SwiftUI, Defaults, KeyboardShortcuts, ScreenCaptureKit

---

### Task 1: Wire up "Capture cursor" setting

**Files:**
- Modify: `LightShotClone/Services/ScreenCaptureService.swift:29`
- Modify: `LightShotClone/Services/ScreenCaptureService.swift:12` (add parameter)
- Modify: `LightShotClone/App/AppDelegate.swift:50` (pass setting)
- Modify: `LightShotClone/App/AppDelegate.swift:281-283` (pass setting for fullscreen)
- Test: `LightShotCloneTests/ScreenCaptureServiceTests.swift` (new)

**Context:** `GeneralSettingsView` has a `captureCursor` toggle backed by `Defaults[.captureCursor]`. Currently `ScreenCaptureService.captureFullScreen()` hardcodes `config.showsCursor = false`. We need to pass the setting through.

**Step 1: Add `showCursor` parameter to `captureFullScreen`**

```swift
// ScreenCaptureService.swift — change signature
static func captureFullScreen(display: SCDisplay, showCursor: Bool = false) async throws -> CGImage {
    // ... existing code ...
    config.showsCursor = showCursor
    // ... rest unchanged ...
}
```

**Step 2: Pass setting from AppDelegate**

In `startRegionCapture()`:
```swift
screenCapture = try? await ScreenCaptureService.captureFullScreen(
    display: display,
    showCursor: Defaults[.captureCursor]
)
```

In `captureAndSaveFullScreen()`:
```swift
let capture = try? await ScreenCaptureService.captureFullScreen(
    display: display,
    showCursor: Defaults[.captureCursor]
)
```

In `captureAndUploadFullScreen()`:
```swift
let capture = try? await ScreenCaptureService.captureFullScreen(
    display: display,
    showCursor: Defaults[.captureCursor]
)
```

**Step 3: Add `import Defaults` to ScreenCaptureService only if needed**

AppDelegate already imports Defaults, so it reads the setting and passes it as a Bool. ScreenCaptureService stays dependency-free.

**Step 4: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 5: Commit**

```bash
git add LightShotClone/Services/ScreenCaptureService.swift LightShotClone/App/AppDelegate.swift
git commit -m "feat: wire up captureCursor setting to ScreenCaptureKit"
```

---

### Task 2: Wire up "Keep selection position" setting

**Files:**
- Modify: `LightShotClone/App/AppDelegate.swift` (save/restore selection rect)

**Context:** `Defaults[.keepSelectionPosition]` exists but is never used. When enabled, the app should remember the last selection rect and pre-populate it on the next capture.

**Step 1: Add stored selection property to AppDelegate**

After `private var currentScreen: NSScreen?` add:
```swift
/// Persisted selection rect for "keep selection position" feature
private var lastSelectionSwiftUIRect: CGRect?
```

**Step 2: Save selection rect after selection completes**

In `onSelectionComplete(swiftUIRect:screen:)`, after `selectionRectForCrop = swiftUIRect`:
```swift
if Defaults[.keepSelectionPosition] {
    lastSelectionSwiftUIRect = swiftUIRect
}
```

**Step 3: Pre-populate selection on next capture**

In `startRegionCapture()`, after `overlay.showOverlays()`:
```swift
if Defaults[.keepSelectionPosition], let lastRect = lastSelectionSwiftUIRect {
    overlay.viewModel.selectionRect = lastRect
    overlay.viewModel.state = .selected(rect: lastRect)
}
```

Wait — `overlay.viewModel` is private. We need a different approach.

**Step 3 (revised): Add method to OverlayWindowController**

In `OverlayWindowController.swift`, add:
```swift
func restoreSelection(_ rect: CGRect) {
    viewModel.selectionRect = rect
}
```

Then in `startRegionCapture()`:
```swift
if Defaults[.keepSelectionPosition], let lastRect = lastSelectionSwiftUIRect {
    overlay.restoreSelection(lastRect)
}
```

**Step 4: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 5: Commit**

```bash
git add LightShotClone/App/AppDelegate.swift LightShotClone/Views/Overlay/OverlayWindowController.swift
git commit -m "feat: wire up keepSelectionPosition setting"
```

---

### Task 3: Wire up "Auto-copy link after upload" setting

**Files:**
- Modify: `LightShotClone/App/AppDelegate.swift:234-248` (uploadScreenshot method)

**Context:** `Defaults[.autoCopyLinkAfterUpload]` exists but the upload always copies link. Make it conditional.

**Step 1: Gate clipboard copy on setting**

In `uploadScreenshot()`, change:
```swift
let link = try await ImageUploadService.uploadToImgur(image)
await MainActor.run {
    if Defaults[.autoCopyLinkAfterUpload] {
        ClipboardService.copyText(link)
    }
    dismissAll()
}
```

Do the same in `captureAndUploadFullScreen()`:
```swift
if let link = try? await ImageUploadService.uploadToImgur(image) {
    await MainActor.run {
        if Defaults[.autoCopyLinkAfterUpload] {
            ClipboardService.copyText(link)
        }
    }
}
```

**Step 2: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 3: Commit**

```bash
git add LightShotClone/App/AppDelegate.swift
git commit -m "feat: wire up autoCopyLinkAfterUpload setting"
```

---

### Task 4: Add screen capture permission error handling

**Files:**
- Modify: `LightShotClone/App/AppDelegate.swift:46-63` (startRegionCapture)

**Context:** If the user denies screen recording permission, `ScreenCaptureService.captureFullScreen()` fails silently (uses `try?`). Nothing happens — very confusing. We should show an alert directing the user to System Settings.

**Step 1: Replace `try?` with `do/catch` and show alert**

Replace `startRegionCapture()`:
```swift
func startRegionCapture() {
    Task { @MainActor in
        do {
            guard let displays = try await ScreenCaptureService.availableDisplays(),
                  let display = displays.first else {
                showErrorAlert(message: "No display found.")
                return
            }
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
        overlay.showOverlays()
        overlayController = overlay

        if Defaults[.keepSelectionPosition], let lastRect = lastSelectionSwiftUIRect {
            overlay.restoreSelection(lastRect)
        }
    }
}
```

Wait — `availableDisplays()` already throws. The current code uses `try?` which swallows errors. Fix: use `do/catch`.

**Step 2: Add permission alert method**

After `showErrorAlert`:
```swift
private func showPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "Screen Recording Permission Required"
    alert.informativeText = "TravisShot needs screen recording permission to capture screenshots.\n\nGo to System Settings > Privacy & Security > Screen Recording and enable TravisShot."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Cancel")

    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Step 3: Also fix fullscreen captures**

In `captureAndSaveFullScreen()` and `captureAndUploadFullScreen()`, replace `try?` with `do/catch` and call `showPermissionAlert()` on failure.

**Step 4: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 5: Commit**

```bash
git add LightShotClone/App/AppDelegate.swift
git commit -m "feat: show permission alert when screen recording denied"
```

---

### Task 5: Add user-facing notifications for copy/save actions

**Files:**
- Modify: `LightShotClone/App/AppDelegate.swift` (copyToClipboard, saveToFile, uploadScreenshot)

**Context:** `Defaults[.showNotifications]` exists but nothing happens. We can't use UserNotifications (requires proper app bundle), but we can use a brief visual feedback approach: `NSSound.beep()` combined with a brief floating label, or simply beep + the existing `showErrorAlert` for failures. For now, use `NSSound` for feedback.

**Step 1: Add notification helper**

```swift
private func showSuccessFeedback(_ message: String) {
    guard Defaults[.showNotifications] else { return }
    NSSound.beep()
}
```

**Step 2: Call after each action**

In `copyToClipboard()`, after `ClipboardService.copy(image)`:
```swift
showSuccessFeedback("Copied to clipboard")
```

In `saveToFile()`, after `await FileSaveService.saveWithDialog(image)`:
```swift
showSuccessFeedback("Screenshot saved")
```

In `uploadScreenshot()`, after `ClipboardService.copyText(link)`:
```swift
showSuccessFeedback("Link copied to clipboard")
```

**Step 3: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 4: Commit**

```bash
git add LightShotClone/App/AppDelegate.swift
git commit -m "feat: wire up showNotifications setting with audio feedback"
```

---

### Task 6: Fix text annotation field width (auto-expanding)

**Files:**
- Modify: `LightShotClone/Views/Annotation/AnnotationCanvasView.swift:178-191`

**Context:** The text field for text annotations has a fixed width of 200px. Long text overflows and is invisible while editing.

**Step 1: Replace fixed-width text field with auto-expanding field**

In `showTextField(at:)`:
```swift
private func showTextField(at point: CGPoint) {
    commitTextField()

    let maxWidth = bounds.width - point.x - 10
    let tf = NSTextField(frame: NSRect(
        x: point.x,
        y: point.y,
        width: min(300, max(100, maxWidth)),
        height: viewModel.currentFontSize + 8
    ))
    tf.isEditable = true
    tf.isBordered = false
    tf.drawsBackground = false
    tf.font = NSFont.systemFont(ofSize: viewModel.currentFontSize)
    tf.textColor = NSColor(viewModel.currentColor)
    tf.focusRingType = .none
    tf.delegate = self
    tf.stringValue = ""
    tf.cell?.isScrollable = true
    tf.cell?.wraps = false
    tf.cell?.lineBreakMode = .byClipping
    addSubview(tf)
    tf.becomeFirstResponder()
    textField = tf
}
```

Key changes:
- Width adapts to available space (clamps between 100 and 300)
- Cell is scrollable for overflow
- No wrapping (single-line intentional — matches Lightshot)

**Step 2: Build and verify**

Run: `swift build -c release 2>&1`
Expected: Build complete

**Step 3: Commit**

```bash
git add LightShotClone/Views/Annotation/AnnotationCanvasView.swift
git commit -m "fix: auto-expand text annotation field to available width"
```

---

### Task 7: Cap undo stack at 50 entries

**Files:**
- Modify: `LightShotClone/ViewModels/AnnotationViewModel.swift:76`
- Modify: `LightShotClone/Views/Annotation/AnnotationCanvasView.swift:212` (commitTextField)
- Test: `LightShotCloneTests/AnnotationViewModelTests.swift` (new)

**Step 1: Write the failing test**

Create `LightShotCloneTests/AnnotationViewModelTests.swift`:
```swift
import XCTest
@testable import TravisShot

final class AnnotationViewModelTests: XCTestCase {
    func testUndoStackCappedAt50() {
        let vm = AnnotationViewModel()
        // Simulate 60 strokes
        for i in 0..<60 {
            vm.beginStroke(at: CGPoint(x: CGFloat(i), y: 0))
            vm.endStroke(at: CGPoint(x: CGFloat(i) + 10, y: 10))
        }
        XCTAssertEqual(vm.annotations.count, 60)
        XCTAssertLessThanOrEqual(vm.undoStack.count, 50)
    }

    func testUndoRestoresPreviousState() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .pen
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(vm.annotations.count, 1)

        vm.undo()
        XCTAssertEqual(vm.annotations.count, 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AnnotationViewModelTests 2>&1`
Expected: `testUndoStackCappedAt50` FAILS because undo stack is unbounded (count == 60)

**Step 3: Cap the undo stack**

In `AnnotationViewModel.swift`, add a private helper and use it everywhere `undoStack.append` is called:

```swift
private let maxUndoSteps = 50

private func pushUndo() {
    undoStack.append(annotations)
    if undoStack.count > maxUndoSteps {
        undoStack.removeFirst(undoStack.count - maxUndoSteps)
    }
}
```

Replace all `undoStack.append(annotations)` calls:
- In `endStroke(at:)`: replace with `pushUndo()`
- In `commitTextIfNeeded()`: replace with `pushUndo()`

Also in `AnnotationCanvasView.swift`, `commitTextField()`:
Replace `viewModel.undoStack.append(viewModel.annotations)` with... wait, this directly accesses the undo stack. We should go through the view model instead.

Add a method to `AnnotationViewModel`:
```swift
func addAnnotation(_ annotation: Annotation) {
    pushUndo()
    annotations.append(annotation)
}
```

Then in `AnnotationCanvasView.commitTextField()`, replace:
```swift
viewModel.undoStack.append(viewModel.annotations)
viewModel.annotations.append(annotation)
```
with:
```swift
viewModel.addAnnotation(annotation)
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter AnnotationViewModelTests 2>&1`
Expected: PASS (both tests)

Also run all tests: `swift test 2>&1`
Expected: All 14 tests pass

**Step 5: Commit**

```bash
git add LightShotClone/ViewModels/AnnotationViewModel.swift LightShotClone/Views/Annotation/AnnotationCanvasView.swift LightShotCloneTests/AnnotationViewModelTests.swift
git commit -m "fix: cap undo stack at 50 entries, add AnnotationViewModel tests"
```

---

### Task 8: Remove dead code

**Files:**
- Modify: `LightShotClone/Models/CaptureState.swift` (keep — used by CaptureViewModel)
- Modify: `LightShotClone/Views/Annotation/AnnotationRenderer.swift:55-148` (remove unused SwiftUI GraphicsContext method)
- Modify: `LightShotClone/Services/PermissionManager.swift` (keep — tests reference it)

**Context:** The explore agent found dead code. Let's clean up only what's truly unused.

**Step 1: Verify CaptureState usage**

Grep for `CaptureState` usage:
- `CaptureState.swift` defines it
- `CaptureViewModel.swift` uses `.idle`, `.selecting`, `.selected`
- **KEEP** — it IS used

**Step 2: Remove unused SwiftUI GraphicsContext draw method**

In `AnnotationRenderer.swift`, remove the `draw(_ annotation: Annotation, in context: inout GraphicsContext)` method and its helper `drawArrowSwiftUI`. These are never called — all rendering goes through the CGContext path.

Delete lines containing:
```swift
/// Draw an annotation into a SwiftUI GraphicsContext (for live preview)
static func draw(_ annotation: Annotation, in context: inout GraphicsContext) { ... }
private static func drawArrowSwiftUI(...) { ... }
```

**Step 3: Build and test**

Run: `swift build -c release 2>&1`
Expected: Build complete (no references to removed methods)

Run: `swift test 2>&1`
Expected: All tests pass

**Step 4: Commit**

```bash
git add LightShotClone/Views/Annotation/AnnotationRenderer.swift
git commit -m "chore: remove unused SwiftUI GraphicsContext rendering code"
```

---

### Task 9: Remove "Auto-close upload window" setting (no upload window exists)

**Files:**
- Modify: `LightShotClone/Models/AppSettings.swift` (remove key)
- Modify: `LightShotClone/Views/Settings/GeneralSettingsView.swift` (remove toggle)

**Context:** `autoCloseUploadWindow` has a UI toggle but there is no upload progress window — uploads happen in the background. This setting is misleading. Remove it.

**Step 1: Remove Defaults key**

In `AppSettings.swift`, delete:
```swift
static let autoCloseUploadWindow = Key<Bool>("autoCloseUploadWindow", default: true)
```

**Step 2: Remove toggle from GeneralSettingsView**

In `GeneralSettingsView.swift`, remove:
```swift
@Default(.autoCloseUploadWindow) var autoCloseUpload
```
and:
```swift
Toggle("Automatically close upload window", isOn: $autoCloseUpload)
```

**Step 3: Build and test**

Run: `swift build -c release 2>&1`
Expected: Build complete

Run: `swift test 2>&1`
Expected: All tests pass

**Step 4: Commit**

```bash
git add LightShotClone/Models/AppSettings.swift LightShotClone/Views/Settings/GeneralSettingsView.swift
git commit -m "chore: remove unused autoCloseUploadWindow setting (no upload window)"
```

---

### Task 10: Build final .app bundle, sign, and create DMG

**Files:**
- No source changes

**Step 1: Build release**

```bash
cd /Users/kaan45186gmail.com/LightShotClone
swift build -c release 2>&1
```
Expected: Build complete

**Step 2: Run all tests**

```bash
swift test 2>&1
```
Expected: All tests pass (14+ tests)

**Step 3: Assemble .app bundle**

```bash
APP_DIR="/Users/kaan45186gmail.com/LightShotClone/build/TravisShot.app"
cp .build/release/TravisShot "$APP_DIR/Contents/MacOS/TravisShot"
```

**Step 4: Code sign**

```bash
codesign --force --deep --sign - "$APP_DIR"
```

**Step 5: Create DMG**

```bash
DMG_PATH="$HOME/Desktop/TravisShot.dmg"
rm -f "$DMG_PATH"
DMG_TMP="/tmp/travisshot_dmg"
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"
cp -R "$APP_DIR" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"
hdiutil create -volname "TravisShot" -srcfolder "$DMG_TMP" -ov -format UDZO "$DMG_PATH"
```

**Step 6: Launch and verify**

```bash
pkill -f TravisShot 2>/dev/null || true
sleep 1
open "$APP_DIR"
```

**Step 7: Manual test checklist**

- [ ] App appears in menu bar (camera icon)
- [ ] Capture Region creates selection overlay
- [ ] Drawing with pen tool works
- [ ] Arrow tool works
- [ ] Text tool works
- [ ] Undo (Cmd+Z) works
- [ ] Copy (Cmd+C) copies image
- [ ] Save (Cmd+S) opens dialog with configured folder
- [ ] Escape dismisses capture
- [ ] App stays alive after dismiss
- [ ] Preferences opens settings window
- [ ] All 3 settings tabs load
- [ ] Hotkeys are reconfigurable
- [ ] Quick save folder is configurable
- [ ] Toolbar buttons have hover animation
- [ ] Toolbar buttons are easy to click

**Step 8: Commit (if any test failures were fixed)**

```bash
git add -A
git commit -m "release: TravisShot v1.0 — fully functional Lightshot clone for macOS"
```
