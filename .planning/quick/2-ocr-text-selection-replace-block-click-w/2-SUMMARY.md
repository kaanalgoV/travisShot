---
phase: quick-2
plan: 1
subsystem: OCR / Text Selection
tags: [ocr, nsTextView, text-selection, vision, macos]
dependency_graph:
  requires: [OCRService, VNRecognizedText API]
  provides: [selectable OCR text overlay, per-character bounding boxes]
  affects: [OCROverlayView, OCRService, AppDelegate]
tech_stack:
  added: []
  patterns: [NSTextView per recognized text block, Vision character-level boundingBox]
key_files:
  created: []
  modified:
    - LightShotClone/Services/OCRService.swift
    - LightShotClone/Views/OCR/OCROverlayView.swift
    - LightShotClone/App/AppDelegate.swift
decisions:
  - VNRecognizedText.boundingBox(for:) returns VNRectangleObservation (not CGRect directly); use .boundingBox property on result
  - Skip Cmd+C shortcut interception in key monitor when OCR overlay is visible so NSTextView handles native copy
  - NSButton pill labels styled with wantsLayer=true for dark background without NSScrollView complexity
  - Font size estimated from average Vision character rect height (80% scale) with blockRect.height*0.7 fallback
metrics:
  duration: ~15 minutes
  completed: 2026-03-07
  tasks_completed: 2
  files_modified: 3
---

# Quick Task 2: OCR Text Selection (Replace Block-Click with I-Beam Selection) Summary

**One-liner:** Replace coarse whole-block OCR copy interaction with native NSTextView-per-block text selection, providing I-beam cursor and character-level drag selection with Cmd+C copy support.

## What Was Built

Replaced the previous click-to-copy-block OCR overlay with a native text selection experience:

1. **OCRService** now provides per-character bounding boxes using `VNRecognizedText.boundingBox(for:)`, stored in a new `CharacterRect` struct and `characterRects` array on `RecognizedTextBlock`.

2. **OCROverlayView** completely rewritten with one `NSTextView` per recognized text block:
   - `isEditable = false`, `isSelectable = true` — read-only but fully selectable
   - I-beam cursor appears automatically when hovering over text regions (native NSTextView behavior)
   - Click-drag selects individual characters and words
   - Cmd+C copies selected text natively (NSTextView handles it)
   - Font size estimated from per-character Vision bounding box heights for visual approximation of original text size
   - Subtle blue highlight (alpha 0.05) + border drawn behind text regions via `draw(_ dirtyRect:)` override

3. **Pill buttons** (`NSButton` with `wantsLayer = true` + dark background) positioned above each text block copy the whole block text on click — replacing the previously drawn pill labels.

4. **AppDelegate**: Two targeted changes:
   - `makeFirstResponder(overlay)` called after adding OCR overlay to ensure NSTextView subviews receive events
   - Cmd+C shortcut skipped in global key monitor when `ocrOverlayView != nil` so NSTextView can handle native copy

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1: OCRService character rects | efe8500 | Add CharacterRect struct + per-character bounding boxes |
| 2: OCROverlayView NSTextView rewrite | 81d7405 | Replace block-click overlay with NSTextView selection |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] VNRecognizedText.boundingBox(for:) returns VNRectangleObservation, not CGRect**
- **Found during:** Task 1 build verification
- **Issue:** Plan comment said the API returns `CGRect?` directly, but the actual macOS Vision API returns `VNRectangleObservation?`
- **Fix:** Access `.boundingBox` property on the `VNRectangleObservation` result to get the `CGRect`
- **Files modified:** `LightShotClone/Services/OCRService.swift`
- **Commit:** efe8500 (fix applied in same commit after first build failure)

**2. [Rule 2 - Missing Critical Functionality] Cmd+C intercepted by global key monitor**
- **Found during:** Task 2 analysis
- **Issue:** AppDelegate's `installKeyMonitor` intercepts Cmd+C globally to copy the screenshot; when the OCR overlay is active this would prevent NSTextView from receiving Cmd+C for selected text copy
- **Fix:** Added `&& self.ocrOverlayView == nil` guard to the Cmd+C shortcut handler in the key monitor
- **Files modified:** `LightShotClone/App/AppDelegate.swift`
- **Commit:** 81d7405

## Self-Check

Files exist:
- LightShotClone/Services/OCRService.swift: FOUND
- LightShotClone/Views/OCR/OCROverlayView.swift: FOUND
- LightShotClone/App/AppDelegate.swift: FOUND

Commits exist:
- efe8500: FOUND
- 81d7405: FOUND

## Self-Check: PASSED
