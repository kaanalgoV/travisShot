---
phase: quick-2
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - LightShotClone/Services/OCRService.swift
  - LightShotClone/Views/OCR/OCROverlayView.swift
  - LightShotClone/App/AppDelegate.swift
autonomous: true
requirements: [OCR-TEXT-SELECT]

must_haves:
  truths:
    - "I-beam cursor appears over recognized text regions"
    - "User can click and drag to select individual characters/words within text regions"
    - "Selected text can be copied with Cmd+C"
    - "Clicking the black pill label still copies the whole block text"
    - "Copy All button still copies all recognized text"
    - "Escape key dismisses the OCR overlay"
  artifacts:
    - path: "LightShotClone/Services/OCRService.swift"
      provides: "Per-character bounding box data from VNRecognizedText"
      contains: "boundingBox(for:)"
    - path: "LightShotClone/Views/OCR/OCROverlayView.swift"
      provides: "Selectable text overlay using NSTextView per text block"
      contains: "NSTextView"
    - path: "LightShotClone/App/AppDelegate.swift"
      provides: "Wiring for new OCR overlay"
      contains: "showOCROverlay"
  key_links:
    - from: "LightShotClone/Services/OCRService.swift"
      to: "LightShotClone/Views/OCR/OCROverlayView.swift"
      via: "RecognizedTextBlock with characterRects"
      pattern: "RecognizedTextBlock"
    - from: "LightShotClone/Views/OCR/OCROverlayView.swift"
      to: "NSTextView"
      via: "embedded text views for native selection"
      pattern: "NSTextView"
---

<objective>
Replace the current OCR block-click-to-copy interaction with native I-beam cursor text selection. Instead of clicking a blue highlight block to copy its entire text, users will be able to click and drag to select individual characters and words within recognized text regions, then copy with Cmd+C.

Purpose: Give users precise text selection (like a text editor) instead of coarse whole-block copying.
Output: Rewritten OCROverlayView with embedded NSTextView instances per text block, updated OCRService providing character-level bounding data.
</objective>

<execution_context>
@/Users/steph/.claude/get-shit-done/workflows/execute-plan.md
@/Users/steph/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@LightShotClone/Services/OCRService.swift
@LightShotClone/Views/OCR/OCROverlayView.swift
@LightShotClone/App/AppDelegate.swift

<interfaces>
<!-- Current contracts the executor needs -->

From LightShotClone/Services/OCRService.swift:
```swift
struct RecognizedTextBlock {
    let text: String
    let boundingBox: CGRect   // Vision normalized coords (0-1, bottom-left origin)
    let confidence: Float
}

enum OCRService {
    static func recognize(in image: CGImage) async throws -> [RecognizedTextBlock]
}
```

From LightShotClone/Services/ClipboardService.swift:
```swift
enum ClipboardService {
    static func copyText(_ text: String)
}
```

From LightShotClone/App/AppDelegate.swift (relevant wiring):
```swift
// Property: private var ocrOverlayView: OCROverlayView?
// Method: showOCROverlay(blocks:selectionRect:) — creates OCROverlayView, positions at selectionRect
// Method: performOCR() — crops image, calls OCRService.recognize, calls showOCROverlay
// Method: dismissAll() — removes ocrOverlayView from superview, nils it
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend OCRService to provide per-character bounding boxes</name>
  <files>LightShotClone/Services/OCRService.swift</files>
  <action>
Extend the `RecognizedTextBlock` struct and `OCRService.recognize` method to provide character-level bounding box data needed for proper text positioning.

1. Add a new struct `CharacterRect` with fields:
   - `character: String`
   - `rect: CGRect` (normalized Vision coordinates, same as boundingBox)

2. Add a new field to `RecognizedTextBlock`:
   - `characterRects: [CharacterRect]`

3. In `OCRService.recognize`, after obtaining each `candidate` (VNRecognizedText), use `candidate.boundingBox(for:)` to get per-character bounding boxes:
   - Get the full string range: `candidate.string.startIndex..<candidate.string.endIndex`
   - Call `try? candidate.boundingBox(for: range)` to get the overall text bounding box (this confirms the API works)
   - Iterate through each character in `candidate.string`, create a range for each character, call `try? candidate.boundingBox(for: charRange)` to get its `VNRectangleObservation`
   - Extract `.boundingBox` from the `VNRectangleObservation` result (it returns a `VNRectangleObservation` whose `boundingBox` property gives the normalized rect)
   - Actually, `boundingBox(for:)` returns an optional `CGRect` directly (normalized coordinates). Use that.
   - Collect into `[CharacterRect]`
   - If `boundingBox(for:)` fails for a character, skip it (compactMap)

4. The method signature stays the same: `static func recognize(in image: CGImage) async throws -> [RecognizedTextBlock]` — only the struct gains the new field.

IMPORTANT: `VNRecognizedText.boundingBox(for:)` takes a `Range<String.Index>` and returns `CGRect?` (normalized 0-1 coordinates with bottom-left origin). This is the Vision framework API on macOS 12+.
  </action>
  <verify>
    <automated>cd /Users/steph/dev/travisShot && swift build 2>&1 | tail -20</automated>
  </verify>
  <done>RecognizedTextBlock now includes characterRects array. OCRService populates per-character bounding boxes using VNRecognizedText.boundingBox(for:). Build succeeds.</done>
</task>

<task type="auto">
  <name>Task 2: Rewrite OCROverlayView with NSTextView-based text selection</name>
  <files>LightShotClone/Views/OCR/OCROverlayView.swift, LightShotClone/App/AppDelegate.swift</files>
  <action>
Completely rewrite `OCROverlayView` to use embedded `NSTextView` instances for each recognized text block, providing native I-beam cursor and click-drag text selection.

**OCROverlayView rewrite:**

1. Keep the same initializer signature: `init(textBlocks:imageSize:onCopyBlock:onCopyAll:onDismiss:)` so AppDelegate wiring stays unchanged.

2. Keep `isFlipped = true` (top-left origin, matching the annotation canvas).

3. For each `RecognizedTextBlock`, create a read-only `NSTextView` positioned at the block's bounding box location (converted from normalized Vision coords to view coords, same math as current `blockRect(for:)`):
   - Create `NSTextView(frame: blockRect)`
   - Set the text view's string to `block.text`
   - Make it read-only: `isEditable = false`
   - Make it selectable: `isSelectable = true`
   - Set transparent background: `drawsBackground = false` (or a very light blue tint like `NSColor.systemBlue.withAlphaComponent(0.08)`)
   - Set the text color to match the original image text as closely as possible — use `NSColor.black` with slight transparency or `NSColor.labelColor`
   - Remove text container insets: set `textContainerInset = NSSize.zero` and `textContainer?.lineFragmentPadding = 0`
   - Disable scrolling: wrap in no scroll, or set `NSScrollView` to have no scrollers. Actually, create `NSTextView` directly (not via `NSScrollView`) by using `NSTextView(frame:)` and adding directly as subview.
   - Attempt to match font size to the block height. Estimate: `fontSize = blockRect.height * 0.75` (since a text line height is roughly 1.3x the font size). Fine-tune: if `characterRects` are available, use the average character rect height to determine font size more accurately: `fontSize = avgCharHeight * imageSize.height * 0.8`.
   - Set the font: `NSFont.systemFont(ofSize: estimatedFontSize)`
   - The text view naturally provides I-beam cursor on hover.

4. Keep the black pill label drawing. Draw it using `draw(_ dirtyRect:)` override on the main view (not on the text views). The pill shows truncated text above each block. When the pill area is clicked, copy the whole block text (use a transparent NSButton overlay on the pill, or detect clicks in `mouseDown` if click is in pill rect but not in any text view).

   Actually, simpler approach: Instead of drawing pills in `draw()`, create small `NSButton` instances styled as pills (dark background, white text, rounded) positioned above each text block. The button's action calls `onCopyBlock(block.text)`. This avoids complex hit-testing between drawn pills and text views.

5. Keep the "Copy All" and dismiss (X) buttons in the top-right corner, same as current implementation.

6. Keep Escape to dismiss: override `keyDown(with:)`, check keyCode 53, call `onDismiss()`.

7. Override `acceptsFirstResponder` to return `true`.

8. Add a subtle highlight background behind each text block region: override `draw(_ dirtyRect:)` to draw a light blue filled rect (alpha 0.08) behind each block area, so users can see where text regions are.

9. For Cmd+C support on selected text: The NSTextView handles this natively — when text is selected in an NSTextView and the user presses Cmd+C, it copies automatically. No extra code needed.

**AppDelegate.swift changes:**

Minimal changes needed since the init signature is preserved:

1. In `showOCROverlay(blocks:selectionRect:)` — no changes needed to the overlay creation. The OCROverlayView init signature stays the same.

2. However, we need to ensure the OCR overlay's NSTextViews can become first responder. The current code adds the overlay as a subview of `annotationWindow.contentView`. The annotation window's content view is a `DrawingCanvasNSView`. We need to ensure mouse events reach the text views.

   The key issue: The `annotationWindow` has `ignoresMouseEvents = false` and the `DrawingCanvasNSView` is the first responder. The OCR overlay is added on top. Since NSTextView subviews are added to the overlay which is a subview of the canvas, mouse events should naturally reach them (AppKit dispatches to the frontmost subview).

   BUT: The `DrawingCanvasNSView` might be intercepting mouse events. To fix this, when the OCR overlay is shown, we should ensure the overlay's text views can receive events. The simplest fix: make the OCR overlay view the first responder when it's added, and ensure it's on top (which it already is since `addSubview` puts it last).

3. In `showOCROverlay`, after adding the overlay as subview, call:
   ```swift
   annotationWindow?.makeFirstResponder(overlay)
   ```
   This ensures the overlay (and its text view subviews) receive keyboard and mouse events.

4. Update the `ocrOverlayView` property type — it stays `OCROverlayView?`, no change needed.

**Font size estimation approach:**
- For each block, compute `blockRect` (same as current code).
- If `characterRects` are available and non-empty, use the average height of character rects (converted to view coords) to estimate font size.
- Otherwise, fall back to `blockRect.height * 0.7`.
- The goal is "close enough" — exact pixel-perfect alignment is not needed. The text should be approximately positioned where the original text was.
  </action>
  <verify>
    <automated>cd /Users/steph/dev/travisShot && swift build 2>&1 | tail -20</automated>
  </verify>
  <done>
- OCROverlayView creates NSTextView per text block with selectable, non-editable text
- I-beam cursor appears when hovering over text regions
- Click-drag selects individual characters/words within a text block
- Cmd+C copies selected text (native NSTextView behavior)
- Pill-shaped buttons above each block copy the whole block text on click
- Copy All and dismiss buttons remain functional
- Escape dismisses the overlay
- Build succeeds with no errors
  </done>
</task>

</tasks>

<verification>
1. Build succeeds: `cd /Users/steph/dev/travisShot && swift build`
2. Run the app, capture a region containing text, click the OCR button
3. Verify I-beam cursor appears over text regions
4. Click and drag within a text block to select individual words
5. Press Cmd+C — selected text copies to clipboard
6. Click a pill label — whole block text copies
7. Click "Copy All" — all text copies
8. Press Escape — overlay dismisses
</verification>

<success_criteria>
- OCR overlay shows selectable text via NSTextView per recognized block
- I-beam cursor on hover over text regions
- Character-level click-drag selection works
- Cmd+C copies selected text
- Pill labels copy whole block text
- Copy All and Escape still work
- No regressions in OCR trigger or dismiss flow
</success_criteria>

<output>
After completion, create `.planning/quick/2-ocr-text-selection-replace-block-click-w/2-SUMMARY.md`
</output>
