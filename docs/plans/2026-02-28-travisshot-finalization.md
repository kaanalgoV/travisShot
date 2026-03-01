# TravisShot Finalization - Design & Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all critical bugs in the LightShot clone, rename to TravisShot, and make it production-ready.

**Architecture:** Pure AppKit NSView for drawing input (replacing broken SwiftUI DragGesture), Retina-aware annotation rendering, configurable Imgur API key, configurable tool shortcuts.

**Tech Stack:** Swift 5.9+, macOS 14+, AppKit + SwiftUI, ScreenCaptureKit, KeyboardShortcuts, Defaults

---

## Critical Bugs Found

1. **Drawing doesn't work** - SwiftUI DragGesture on NSViewRepresentable (ScrollWheelCaptureView) doesn't forward mouse events correctly. The window intercepts drags.
2. **Scroll wheel fires twice** - Both AppDelegate.installScrollMonitor() and ScrollWheelNSView handle scroll events.
3. **Retina scaling broken** - renderAnnotations creates a 1x CGContext but the captured image is 2x.
4. **Text rendering mismatch** - SwiftUI uses top-left origin, CGContext uses bottom-left. Text position differs between preview and export.
5. **Placeholder Imgur API key** - Upload always fails.
6. **Hardcoded tool shortcuts** - Not configurable.
7. **App still named LightShotClone** - Should be TravisShot.

---

### Task 1: Fix Drawing Input - Replace SwiftUI Gesture with AppKit NSView

**Root Cause:** `AnnotationCanvasView` uses a `DragGesture` on `ScrollWheelCaptureView` (NSViewRepresentable). SwiftUI gestures on NSViewRepresentable views don't reliably forward mouse events.

**Fix:** Replace `ScrollWheelCaptureView` + `DragGesture` combo with a single `DrawingInputNSView` that handles `mouseDown/mouseDragged/mouseUp` AND `scrollWheel` natively.

**Files:**
- Modify: `LightShotClone/Views/Annotation/AnnotationCanvasView.swift`

**Changes:**
- Remove `ScrollWheelCaptureView` and `ScrollWheelNSView`
- Create `DrawingInputNSView` with `isFlipped = true` (matches SwiftUI coordinates)
- Create `DrawingInputRepresentable` wrapper
- Update `AnnotationCanvasView` to use the new input view

### Task 2: Fix Scroll Wheel Duplication

**Files:**
- Modify: `LightShotClone/App/AppDelegate.swift`

**Changes:**
- Remove `installScrollMonitor()` method
- Remove `scrollMonitor` property
- Remove scroll monitor cleanup from `removeKeyMonitor()`

### Task 3: Fix Retina Scaling in Annotation Export

**Files:**
- Modify: `LightShotClone/ViewModels/AnnotationViewModel.swift`

**Changes:**
- Accept `scale` parameter in `renderAnnotations(onto:selectionRect:scale:)`
- Create CGContext at `width * scale, height * scale`
- Apply scale transform before drawing annotations
- Flip Y axis for correct coordinate mapping
- Fix text rendering with proper text matrix

### Task 4: Fix Text Rendering in CGContext

**Files:**
- Modify: `LightShotClone/Views/Annotation/AnnotationRenderer.swift`

**Changes:**
- Use `NSString.draw(at:withAttributes:)` via NSGraphicsContext for text export
- Ensures coordinate system consistency between preview and export

### Task 5: Rename to TravisShot

**Files:**
- Modify: `Package.swift` - target name, package name
- Modify: `LightShotClone/App/LightShotCloneApp.swift` - struct name, menu text
- Modify: `LightShotClone/App/AppDelegate.swift` - any references
- Modify: `LightShotClone/Models/AppSettings.swift` - if needed

### Task 6: Make Imgur Client-ID Configurable

**Files:**
- Modify: `LightShotClone/Models/AppSettings.swift` - add imgurClientID key
- Modify: `LightShotClone/Services/ImageUploadService.swift` - read from Defaults
- Modify: `LightShotClone/Views/Settings/FormatSettingsView.swift` - add API key field
- Modify: `LightShotClone/App/AppDelegate.swift` - show error feedback

### Task 7: Add App Icon

**Files:**
- Modify: `LightShotClone/Resources/Assets.xcassets/AppIcon.appiconset/`

### Task 8: Build, Test, Verify
