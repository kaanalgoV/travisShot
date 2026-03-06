---
phase: quick-ocr
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - LightShotClone/Services/OCRService.swift
  - LightShotClone/Views/Toolbar/EditingToolbarView.swift
  - LightShotClone/Views/Toolbar/EditingToolbarController.swift
  - LightShotClone/Views/OCR/OCROverlayView.swift
  - LightShotClone/App/AppDelegate.swift
  - LightShotClone/Models/AppSettings.swift
autonomous: true
requirements: [OCR-01]

must_haves:
  truths:
    - "User can click an OCR button in the editing toolbar to recognize text in the selected region"
    - "Recognized text blocks appear as highlightable/selectable regions overlaid on the capture"
    - "User can click a recognized text block to copy its text to the clipboard"
    - "User can click 'Copy All' to copy all recognized text at once"
    - "OCR mode can be dismissed to return to normal annotation mode"
  artifacts:
    - path: "LightShotClone/Services/OCRService.swift"
      provides: "Vision framework OCR using VNRecognizeTextRequest"
      exports: ["OCRService", "RecognizedTextBlock"]
    - path: "LightShotClone/Views/OCR/OCROverlayView.swift"
      provides: "NSView overlay showing recognized text regions as clickable highlights"
    - path: "LightShotClone/Views/Toolbar/EditingToolbarView.swift"
      provides: "OCR button added to toolbar"
    - path: "LightShotClone/Views/Toolbar/EditingToolbarController.swift"
      provides: "onOCR callback wiring"
  key_links:
    - from: "LightShotClone/Views/Toolbar/EditingToolbarView.swift"
      to: "AppDelegate.swift"
      via: "onOCR callback through EditingToolbarController"
      pattern: "onOCR"
    - from: "AppDelegate.swift"
      to: "OCRService.swift"
      via: "performOCR call with cropped CGImage"
      pattern: "OCRService\\.recognize"
    - from: "OCRService.swift"
      to: "OCROverlayView.swift"
      via: "RecognizedTextBlock array passed to overlay"
      pattern: "RecognizedTextBlock"
    - from: "OCROverlayView.swift"
      to: "ClipboardService.swift"
      via: "Copy text on click"
      pattern: "ClipboardService\\.copyText"
---

<objective>
Add OCR text recognition to TravisShot's editing toolbar. When the user clicks the OCR button, Apple's Vision framework scans the selected screenshot region for text. Recognized text blocks appear as highlighted, clickable regions overlaid on the capture. Clicking a block copies its text; a "Copy All" button copies everything.

Purpose: Enable users to quickly extract and copy text from screenshots without leaving the app.
Output: OCR button in toolbar, OCRService using VNRecognizeTextRequest, interactive text overlay with copy-on-click.
</objective>

<execution_context>
@/Users/steph/.claude/get-shit-done/workflows/execute-plan.md
@/Users/steph/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@LightShotClone/Models/AnnotationTool.swift
@LightShotClone/Models/Annotation.swift
@LightShotClone/Models/AppSettings.swift
@LightShotClone/ViewModels/AnnotationViewModel.swift
@LightShotClone/Views/Toolbar/EditingToolbarView.swift
@LightShotClone/Views/Toolbar/EditingToolbarController.swift
@LightShotClone/Views/Annotation/AnnotationCanvasView.swift
@LightShotClone/App/AppDelegate.swift
@LightShotClone/Services/ClipboardService.swift
@LightShotClone/Services/ScreenCaptureService.swift

<interfaces>
<!-- Key types and contracts the executor needs. -->

From LightShotClone/Views/Toolbar/EditingToolbarController.swift:
```swift
final class EditingToolbarController {
    let annotationVM: AnnotationViewModel
    private(set) var isFrozen: Bool
    func show(near selectionRect: NSRect, onToggleFreeze: @escaping () -> Void, onClose: @escaping () -> Void)
    func setFrozen(_ frozen: Bool)
    func dismiss()
    func reposition(near selectionRect: NSRect)
}
```

From LightShotClone/Views/Toolbar/EditingToolbarView.swift:
```swift
struct EditingToolbarView: View {
    @ObservedObject var annotationVM: AnnotationViewModel
    var isFrozen: Bool
    var onToggleFreeze: () -> Void
    var onClose: () -> Void
}

struct ToolButton: View {
    let systemImage: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void
}
```

From LightShotClone/Services/ClipboardService.swift:
```swift
enum ClipboardService {
    static func copyText(_ text: String)
}
```

From AppDelegate (relevant properties):
```swift
private var selectedCapture: CGImage?
private var selectionRectForCrop: CGRect?
private var currentScreen: NSScreen?
private var editingToolbar: EditingToolbarController?
private var annotationWindow: NSWindow?
private var drawingCanvas: DrawingCanvasNSView?
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create OCRService and RecognizedTextBlock model</name>
  <files>LightShotClone/Services/OCRService.swift</files>
  <action>
Create `LightShotClone/Services/OCRService.swift` with:

1. A `RecognizedTextBlock` struct containing:
   - `text: String` — the recognized text content
   - `boundingBox: CGRect` — normalized bounding box from Vision (0-1 range, bottom-left origin)
   - `confidence: Float` — recognition confidence

2. An `OCRService` enum with a static async method:
   ```swift
   static func recognize(in image: CGImage) async throws -> [RecognizedTextBlock]
   ```
   Implementation:
   - Create a `VNRecognizeTextRequest` with `.accurate` recognition level
   - Set `recognitionLanguages` to `["en"]` (can be expanded later)
   - Set `usesLanguageCorrection = true`
   - Create a `VNImageRequestHandler` with the CGImage
   - Perform the request on a background thread using `withCheckedThrowingContinuation`
   - Extract results from `VNRecognizedTextObservation` array
   - For each observation, get the top candidate (`topCandidates(1).first`)
   - Map to `RecognizedTextBlock` with the observation's `boundingBox` and candidate's `confidence`
   - Filter out results with confidence below 0.3
   - Return the array sorted by position (top-to-bottom, left-to-right using the boundingBox y then x)

   Import `Vision` framework. No external dependencies needed — Vision is built into macOS.

   Add an `OCRError` enum with cases: `noResults`, `recognitionFailed(Error)`
  </action>
  <verify>
    <automated>cd /Users/steph/dev/travisShot && swift build 2>&1 | tail -5</automated>
  </verify>
  <done>OCRService.swift exists, compiles, exposes `recognize(in:)` that returns `[RecognizedTextBlock]` using VNRecognizeTextRequest</done>
</task>

<task type="auto">
  <name>Task 2: Create OCR overlay view and wire OCR button into toolbar + AppDelegate</name>
  <files>
    LightShotClone/Views/OCR/OCROverlayView.swift,
    LightShotClone/Views/Toolbar/EditingToolbarView.swift,
    LightShotClone/Views/Toolbar/EditingToolbarController.swift,
    LightShotClone/App/AppDelegate.swift,
    LightShotClone/Models/AppSettings.swift
  </files>
  <action>
**A. Create OCROverlayView (NSView subclass, NOT SwiftUI — matches DrawingCanvasNSView pattern):**

Create `LightShotClone/Views/OCR/OCROverlayView.swift`:

An `OCROverlayView: NSView` that displays recognized text blocks as interactive highlights over the capture area. Constructor takes:
- `textBlocks: [RecognizedTextBlock]` — the OCR results
- `imageSize: CGSize` — the size of the captured image region (in points, matching the selection rect)
- `onCopyBlock: (String) -> Void` — callback when user clicks a text block
- `onCopyAll: () -> Void` — callback for copy-all button
- `onDismiss: () -> Void` — callback to exit OCR mode

Properties:
- `isFlipped = true` (to match canvas coordinate system)
- `hoveredBlockIndex: Int?` — tracks which block the mouse is over
- A tracking area for mouse moved events

Drawing (`draw(_:)`):
- For each `RecognizedTextBlock`, convert its normalized `boundingBox` (Vision uses bottom-left origin, 0-1 range) to view coordinates:
  ```swift
  let x = block.boundingBox.origin.x * imageSize.width
  let y = (1 - block.boundingBox.origin.y - block.boundingBox.height) * imageSize.height  // flip Y for top-left origin
  let w = block.boundingBox.width * imageSize.width
  let h = block.boundingBox.height * imageSize.height
  ```
- Draw a semi-transparent blue highlight rect (NSColor.systemBlue.withAlphaComponent(0.15)) for each block
- For the hovered block, use stronger opacity (0.35) and a border (systemBlue, 2pt)
- Draw the recognized text inside or above each block in a small label (NSFont.systemFont(ofSize: 11), white on dark background pill)

Mouse handling:
- `mouseMoved`: update `hoveredBlockIndex` based on which block rect contains the mouse point, call `needsDisplay = true`
- `mouseDown`: if hoveredBlockIndex is set, call `onCopyBlock(textBlocks[hoveredBlockIndex].text)` and briefly flash the block green to indicate copy success
- `updateTrackingAreas`: install a tracking area for `.mouseMoved`, `.activeInKeyWindow`

Add a "Copy All" button as a small floating NSButton or draw it as a custom rect in the top-right corner of the view. When clicked, concatenate all text blocks with newlines and call `onCopyAll()`.

Add an "x" dismiss button (or respond to Escape) to call `onDismiss()`.

**B. Add onOCR callback to EditingToolbarController:**

In `EditingToolbarController.swift`:
- Add `private var onOCR: (() -> Void)?` property
- Add `onOCR` parameter to the `show(near:...)` method signature: `onOCR: @escaping () -> Void = {}`
- Store it: `self.onOCR = onOCR`
- Pass it through to `makeView()`: add `onOCR` parameter to `EditingToolbarView`

In `EditingToolbarView.swift`:
- Add `var onOCR: () -> Void` property
- Add an OCR button AFTER the blur tool and BEFORE the color picker, using a Divider to separate annotation tools from the OCR action:
  ```swift
  Divider()
      .frame(width: 28)
      .padding(.vertical, 2)

  ToolButton(
      systemImage: "doc.text.viewfinder",
      isSelected: false,
      tooltip: "OCR Text Recognition (O)"
  ) {
      onOCR()
  }
  ```
- Update the `makeView()` in `EditingToolbarController` to pass the `onOCR` closure

**C. Add shortcut key for OCR in AppSettings.swift:**

In `AppSettings.swift`, add to `Defaults.Keys`:
```swift
static let shortcutOCR = Key<String>("shortcutOCR", default: "o")
```

**D. Wire OCR in AppDelegate.swift:**

Add a new private property:
```swift
private var ocrOverlayView: OCROverlayView?
```

In `onSelectionComplete`, when creating the `EditingToolbarController`, add the `onOCR` callback:
```swift
editToolbar.show(
    near: screenRect,
    onToggleFreeze: { ... },  // existing
    onOCR: { [weak self] in self?.performOCR() },
    onClose: { ... }  // existing
)
```

Create a `performOCR()` method:
```swift
private func performOCR() {
    guard let capture = selectedCapture, let cropRect = selectionRectForCrop, let screen = currentScreen else { return }

    // Crop to selection
    let screenWidth = screen.frame.width
    let scale = CGFloat(capture.width) / screenWidth
    let scaledRect = CGRect(
        x: cropRect.origin.x * scale,
        y: cropRect.origin.y * scale,
        width: cropRect.width * scale,
        height: cropRect.height * scale
    )
    guard let croppedImage = capture.cropping(to: scaledRect) else { return }

    Task { @MainActor in
        do {
            let blocks = try await OCRService.recognize(in: croppedImage)
            if blocks.isEmpty {
                showSuccessFeedback("No text found")
                return
            }
            showOCROverlay(blocks: blocks, selectionRect: cropRect)
        } catch {
            showSuccessFeedback("OCR failed")
        }
    }
}
```

Create `showOCROverlay(blocks:selectionRect:)`:
- Create an `OCROverlayView` with the text blocks, positioned and sized to match the selection rect within the annotation window
- The `imageSize` parameter should be `selectionRect.size` (the selection dimensions in points)
- Position the OCR overlay at `selectionRect.origin` within the annotation window's content view (which is the full screen canvas)
- Add it as a subview of the annotation window's content view, ABOVE the drawing canvas
- Set `onCopyBlock` to: copy the text via `ClipboardService.copyText(text)` and call `showSuccessFeedback("Copied: (text prefix)")`
- Set `onCopyAll` to: join all block texts with newlines, copy via `ClipboardService.copyText`, show feedback, then dismiss OCR overlay
- Set `onDismiss` to: remove the OCR overlay from superview, set `ocrOverlayView = nil`
- Store reference in `self.ocrOverlayView`

Add OCR keyboard shortcut in `installKeyMonitor()`, in the no-modifier section (alongside blur, number, etc.):
```swift
if char == Defaults[.shortcutOCR] { self.performOCR(); return nil }
```

In `dismissAll()`, add cleanup:
```swift
ocrOverlayView?.removeFromSuperview()
ocrOverlayView = nil
```

**E. Update toolbar height:**

In `EditingToolbarController.swift`, increase `toolbarHeight` from 400 to 440 to accommodate the new OCR button.
  </action>
  <verify>
    <automated>cd /Users/steph/dev/travisShot && swift build 2>&1 | tail -10</automated>
  </verify>
  <done>
    - OCR button visible in editing toolbar with "doc.text.viewfinder" icon
    - Pressing "O" key or clicking the button triggers OCR on the selected region
    - Recognized text blocks appear as highlighted clickable regions on the overlay
    - Clicking a block copies its text to clipboard
    - "Copy All" copies all recognized text
    - OCR overlay can be dismissed to return to annotation mode
    - Project compiles without errors
  </done>
</task>

</tasks>

<verification>
1. `swift build` completes without errors
2. Launch app, capture a region containing text
3. Click the OCR button (or press "O") in the editing toolbar
4. Verify text blocks appear as blue highlighted regions over the captured text
5. Hover over a text block — highlight intensifies
6. Click a text block — text copies to clipboard (verify with Cmd+V in a text editor)
7. Click "Copy All" — all text copied, OCR overlay dismissed
8. Press Escape or click dismiss — OCR overlay removed, back to normal annotation mode
</verification>

<success_criteria>
- OCR button is present in the editing toolbar
- Vision framework recognizes text in the captured screenshot region
- Recognized text blocks are displayed as interactive highlighted regions
- Clicking a text block copies its content to the system clipboard
- "Copy All" concatenates and copies all recognized text
- OCR mode can be dismissed cleanly
- No regressions to existing annotation tools
- Project builds and runs without errors
</success_criteria>

<output>
After completion, create `.planning/quick/1-ocr-text-recognition-button-select-and-c/1-SUMMARY.md`
</output>
