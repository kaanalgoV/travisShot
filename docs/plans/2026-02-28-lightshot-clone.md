# LightShot Clone for macOS - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a pixel-perfect 1:1 clone of Lightshot (screenshot tool) as a native macOS menu bar app with area selection, annotation tools, clipboard/save/upload actions, and global hotkeys.

**Architecture:** Native macOS app using AppKit for window management (borderless overlay windows, floating toolbar panels) with SwiftUI views for UI. ScreenCaptureKit for screen capture. Custom Canvas-based annotation engine. Menu bar app with no dock icon (`LSUIElement`).

**Tech Stack:** Swift 5.9+, macOS 14+, AppKit + SwiftUI, ScreenCaptureKit, KeyboardShortcuts (SPM), LaunchAtLogin (SPM), Imgur API v3 for image upload.

---

## Project Structure

```
LightShotClone/
├── LightShotClone/
│   ├── App/
│   │   ├── LightShotCloneApp.swift          # SwiftUI App entry point with MenuBarExtra
│   │   ├── AppDelegate.swift                 # AppKit delegate for overlay/hotkey management
│   │   └── Info.plist                        # LSUIElement, permissions descriptions
│   ├── Models/
│   │   ├── Annotation.swift                  # Annotation data model
│   │   ├── AnnotationTool.swift              # Tool enum (pen, line, arrow, rect, text, marker)
│   │   ├── CaptureState.swift                # State machine for capture flow
│   │   └── AppSettings.swift                 # User preferences model
│   ├── Services/
│   │   ├── ScreenCaptureService.swift        # ScreenCaptureKit wrapper
│   │   ├── ClipboardService.swift            # NSPasteboard copy
│   │   ├── FileSaveService.swift             # NSSavePanel + file writing
│   │   ├── ImageUploadService.swift          # Imgur API upload
│   │   ├── PermissionManager.swift           # Screen Recording + Accessibility checks
│   │   └── PrintService.swift               # NSPrintOperation wrapper
│   ├── Views/
│   │   ├── Overlay/
│   │   │   ├── OverlayWindowController.swift # Creates borderless overlay NSWindows
│   │   │   ├── SelectionOverlayView.swift    # SwiftUI selection + dimming view
│   │   │   └── DimmingShape.swift            # eoFill shape with rectangular cutout
│   │   ├── Toolbar/
│   │   │   ├── EditingToolbarController.swift  # NSPanel for vertical editing toolbar
│   │   │   ├── EditingToolbarView.swift        # SwiftUI: pen, line, arrow, rect, text, marker, color, undo, close
│   │   │   ├── ActionToolbarController.swift   # NSPanel for horizontal action toolbar
│   │   │   └── ActionToolbarView.swift         # SwiftUI: upload, share, search, print, copy, save
│   │   ├── Annotation/
│   │   │   ├── AnnotationCanvasView.swift    # SwiftUI Canvas rendering annotations
│   │   │   └── AnnotationRenderer.swift      # Drawing logic for each tool type
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift            # TabView with all settings tabs
│   │   │   ├── GeneralSettingsView.swift     # General preferences
│   │   │   ├── HotkeySettingsView.swift      # Hotkey customization
│   │   │   └── FormatSettingsView.swift      # Upload/save format settings
│   │   └── ColorPicker/
│   │       └── ColorPickerPopover.swift      # Color picker with preset grid
│   ├── ViewModels/
│   │   ├── CaptureViewModel.swift            # Manages capture flow state
│   │   └── AnnotationViewModel.swift         # Manages annotations, undo stack, tool state
│   ├── Utilities/
│   │   ├── CoordinateConverter.swift         # AppKit <-> CG coordinate conversion
│   │   └── MultiMonitorManager.swift         # Multi-display enumeration and handling
│   └── Resources/
│       └── Assets.xcassets                   # App icon, toolbar icons
├── LightShotCloneTests/
│   ├── AnnotationTests.swift
│   ├── CaptureStateTests.swift
│   ├── CoordinateConverterTests.swift
│   ├── ClipboardServiceTests.swift
│   └── FileSaveServiceTests.swift
└── Package.swift
```

---

## Task 1: Create Xcode Project and SPM Dependencies

**Files:**
- Create: `LightShotClone/Package.swift`
- Create: `LightShotClone/LightShotClone/App/LightShotCloneApp.swift`
- Create: `LightShotClone/LightShotClone/App/AppDelegate.swift`
- Create: `LightShotClone/LightShotClone/App/Info.plist`

**Step 1: Create the Swift Package manifest**

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LightShotClone",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LightShotClone",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                "Defaults",
            ],
            path: "LightShotClone"
        ),
        .testTarget(
            name: "LightShotCloneTests",
            dependencies: ["LightShotClone"],
            path: "LightShotCloneTests"
        ),
    ]
)
```

**Step 2: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>LightShot needs screen recording permission to capture screenshots.</string>
    <key>CFBundleName</key>
    <string>LightShot</string>
    <key>CFBundleIdentifier</key>
    <string>com.lightshot.clone</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

**Step 3: Create minimal App entry point**

```swift
// LightShotClone/App/LightShotCloneApp.swift
import SwiftUI

@main
struct LightShotCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LightShot", systemImage: "camera.viewfinder") {
            Button("Capture Region") {
                appDelegate.startRegionCapture()
            }
            .keyboardShortcut("9", modifiers: [.command, .shift])

            Divider()

            Button("Quit LightShot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            Text("Settings placeholder")
        }
    }
}
```

**Step 4: Create minimal AppDelegate**

```swift
// LightShotClone/App/AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func startRegionCapture() {
        print("Region capture triggered")
    }
}
```

**Step 5: Verify it compiles**

Run: `cd LightShotClone && swift build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git init
git add -A
git commit -m "feat: initial project setup with SPM dependencies and menu bar app skeleton"
```

---

## Task 2: Permission Manager

**Files:**
- Create: `LightShotClone/LightShotClone/Services/PermissionManager.swift`
- Create: `LightShotCloneTests/PermissionManagerTests.swift`

**Step 1: Write the test**

```swift
// LightShotCloneTests/PermissionManagerTests.swift
import XCTest
@testable import LightShotClone

final class PermissionManagerTests: XCTestCase {
    func testScreenRecordingPermissionCheckDoesNotCrash() {
        // This just verifies the API call works without crashing
        let _ = PermissionManager.hasScreenRecordingPermission
    }

    func testAccessibilityPermissionCheckDoesNotCrash() {
        let _ = PermissionManager.hasAccessibilityPermission
    }

    func testSystemSettingsURLsAreValid() {
        XCTAssertNotNil(PermissionManager.screenRecordingSettingsURL)
        XCTAssertNotNil(PermissionManager.accessibilitySettingsURL)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter PermissionManagerTests`
Expected: FAIL (module/type not found)

**Step 3: Write PermissionManager**

```swift
// LightShotClone/LightShotClone/Services/PermissionManager.swift
import AppKit
import CoreGraphics

enum PermissionManager {
    // MARK: - Screen Recording

    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Accessibility

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - System Settings URLs

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )

    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    static func openScreenRecordingSettings() {
        if let url = screenRecordingSettingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAccessibilitySettings() {
        if let url = accessibilitySettingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter PermissionManagerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Services/PermissionManager.swift LightShotCloneTests/PermissionManagerTests.swift
git commit -m "feat: add PermissionManager for screen recording and accessibility checks"
```

---

## Task 3: Screen Capture Service

**Files:**
- Create: `LightShotClone/LightShotClone/Services/ScreenCaptureService.swift`
- Create: `LightShotClone/LightShotClone/Utilities/MultiMonitorManager.swift`
- Create: `LightShotClone/LightShotClone/Utilities/CoordinateConverter.swift`
- Create: `LightShotCloneTests/CoordinateConverterTests.swift`

**Step 1: Write CoordinateConverter test**

```swift
// LightShotCloneTests/CoordinateConverterTests.swift
import XCTest
@testable import LightShotClone

final class CoordinateConverterTests: XCTestCase {
    func testFlipYCoordinate() {
        // Screen height 1080, rect at y=100 with height=200
        // In CG top-left coords: y = 1080 - 100 - 200 = 780
        let result = CoordinateConverter.flipY(
            rect: CGRect(x: 50, y: 100, width: 300, height: 200),
            inScreenHeight: 1080
        )
        XCTAssertEqual(result.origin.x, 50)
        XCTAssertEqual(result.origin.y, 780)
        XCTAssertEqual(result.width, 300)
        XCTAssertEqual(result.height, 200)
    }

    func testNormalizeRect() {
        // Negative-sized rect (dragged right-to-left)
        let rect = CGRect(x: 300, y: 400, width: -200, height: -150)
        let normalized = CoordinateConverter.normalize(rect)
        XCTAssertEqual(normalized.origin.x, 100)
        XCTAssertEqual(normalized.origin.y, 250)
        XCTAssertEqual(normalized.width, 200)
        XCTAssertEqual(normalized.height, 150)
    }

    func testScaleForRetina() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let scaled = CoordinateConverter.scale(rect, by: 2.0)
        XCTAssertEqual(scaled.origin.x, 20)
        XCTAssertEqual(scaled.origin.y, 40)
        XCTAssertEqual(scaled.width, 200)
        XCTAssertEqual(scaled.height, 100)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter CoordinateConverterTests`
Expected: FAIL

**Step 3: Write CoordinateConverter**

```swift
// LightShotClone/LightShotClone/Utilities/CoordinateConverter.swift
import CoreGraphics

enum CoordinateConverter {
    /// Flip Y coordinate from AppKit (bottom-left origin) to CG (top-left origin)
    static func flipY(rect: CGRect, inScreenHeight screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Normalize a rect that may have negative width/height (from dragging in reverse)
    static func normalize(_ rect: CGRect) -> CGRect {
        CGRect(
            x: min(rect.origin.x, rect.origin.x + rect.width),
            y: min(rect.origin.y, rect.origin.y + rect.height),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }

    /// Scale a rect by a factor (e.g., for Retina displays)
    static func scale(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x * factor,
            y: rect.origin.y * factor,
            width: rect.width * factor,
            height: rect.height * factor
        )
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter CoordinateConverterTests`
Expected: PASS

**Step 5: Write MultiMonitorManager**

```swift
// LightShotClone/LightShotClone/Utilities/MultiMonitorManager.swift
import AppKit

enum MultiMonitorManager {
    /// Get all connected screens
    static var allScreens: [NSScreen] {
        NSScreen.screens
    }

    /// Find which screen contains a given point in global coordinates
    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSPointInRect(point, $0.frame) }
    }

    /// Get the CGDirectDisplayID for a given NSScreen
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else { return nil }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    /// Union of all screen frames
    static var totalFrame: NSRect {
        NSScreen.screens.reduce(.zero) { $0.union($1.frame) }
    }
}
```

**Step 6: Write ScreenCaptureService**

```swift
// LightShotClone/LightShotClone/Services/ScreenCaptureService.swift
import AppKit
import ScreenCaptureKit

enum ScreenCaptureError: Error {
    case noDisplayFound
    case captureFailedWithError(Error)
    case noPermission
}

final class ScreenCaptureService {
    /// Capture the entire screen as a CGImage (excluding our own app windows)
    static func captureFullScreen(display: SCDisplay) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Exclude our own app from the capture
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let excludedApps = content.applications.filter { $0.bundleIdentifier == bundleID }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.scaleFactor = 2 // Retina
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    /// Get all available displays as SCDisplay objects
    static func availableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }

    /// Crop a CGImage to a given rect
    static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        image.cropping(to: rect)
    }
}
```

**Step 7: Commit**

```bash
git add LightShotClone/LightShotClone/Services/ScreenCaptureService.swift \
        LightShotClone/LightShotClone/Utilities/CoordinateConverter.swift \
        LightShotClone/LightShotClone/Utilities/MultiMonitorManager.swift \
        LightShotCloneTests/CoordinateConverterTests.swift
git commit -m "feat: add ScreenCaptureService, CoordinateConverter, and MultiMonitorManager"
```

---

## Task 4: Data Models (Annotation, Tool, CaptureState, AppSettings)

**Files:**
- Create: `LightShotClone/LightShotClone/Models/AnnotationTool.swift`
- Create: `LightShotClone/LightShotClone/Models/Annotation.swift`
- Create: `LightShotClone/LightShotClone/Models/CaptureState.swift`
- Create: `LightShotClone/LightShotClone/Models/AppSettings.swift`
- Create: `LightShotCloneTests/AnnotationTests.swift`
- Create: `LightShotCloneTests/CaptureStateTests.swift`

**Step 1: Write Annotation and CaptureState tests**

```swift
// LightShotCloneTests/AnnotationTests.swift
import XCTest
@testable import LightShotClone

final class AnnotationTests: XCTestCase {
    func testAnnotationCreation() {
        let annotation = Annotation(
            tool: .arrow,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 200),
            color: .red,
            lineWidth: 2
        )
        XCTAssertEqual(annotation.tool, .arrow)
        XCTAssertEqual(annotation.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(annotation.endPoint, CGPoint(x: 100, y: 200))
    }

    func testAnnotationBoundingRect() {
        let annotation = Annotation(
            tool: .rectangle,
            startPoint: CGPoint(x: 100, y: 50),
            endPoint: CGPoint(x: 50, y: 150),
            color: .red,
            lineWidth: 2
        )
        let bounds = annotation.boundingRect
        XCTAssertEqual(bounds.origin.x, 50)
        XCTAssertEqual(bounds.origin.y, 50)
        XCTAssertEqual(bounds.width, 50)
        XCTAssertEqual(bounds.height, 100)
    }

    func testFreehandAnnotation() {
        var annotation = Annotation(
            tool: .pen,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: 0),
            color: .red,
            lineWidth: 2
        )
        annotation.freehandPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 20, y: 5)
        ]
        XCTAssertEqual(annotation.freehandPoints.count, 3)
    }
}

// LightShotCloneTests/CaptureStateTests.swift
import XCTest
@testable import LightShotClone

final class CaptureStateTests: XCTestCase {
    func testInitialStateIsIdle() {
        let state = CaptureState.idle
        if case .idle = state {
            // pass
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testStateTransitions() {
        // Valid flow: idle -> selecting -> selected -> annotating -> idle
        let states: [CaptureState] = [
            .idle,
            .selecting(origin: CGPoint(x: 10, y: 20)),
            .selected(rect: CGRect(x: 10, y: 20, width: 100, height: 80)),
            .annotating,
            .idle
        ]
        XCTAssertEqual(states.count, 5)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter "AnnotationTests|CaptureStateTests"`
Expected: FAIL

**Step 3: Write the models**

```swift
// LightShotClone/LightShotClone/Models/AnnotationTool.swift
import Foundation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case line
    case arrow
    case rectangle
    case text
    case marker

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .marker: return "Marker"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .marker: return "highlighter"
        }
    }
}
```

```swift
// LightShotClone/LightShotClone/Models/Annotation.swift
import SwiftUI

struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: Color
    var lineWidth: CGFloat
    var text: String = ""
    var fontSize: CGFloat = 16
    var freehandPoints: [CGPoint] = []

    /// The normalized bounding rect of this annotation
    var boundingRect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }
}
```

```swift
// LightShotClone/LightShotClone/Models/CaptureState.swift
import Foundation

enum CaptureState {
    case idle
    case selecting(origin: CGPoint)
    case selected(rect: CGRect)
    case annotating
}
```

```swift
// LightShotClone/LightShotClone/Models/AppSettings.swift
import Defaults
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureRegion = Self("captureRegion", default: .init(.nine, modifiers: [.command, .shift]))
    static let captureFullScreen = Self("captureFullScreen")
    static let instantUploadFullScreen = Self("instantUploadFullScreen")
}

extension Defaults.Keys {
    static let autoCopyLinkAfterUpload = Key<Bool>("autoCopyLinkAfterUpload", default: true)
    static let autoCloseUploadWindow = Key<Bool>("autoCloseUploadWindow", default: true)
    static let showNotifications = Key<Bool>("showNotifications", default: true)
    static let keepSelectionPosition = Key<Bool>("keepSelectionPosition", default: false)
    static let captureCursor = Key<Bool>("captureCursor", default: false)
    static let uploadFormat = Key<String>("uploadFormat", default: "png")
    static let jpegQuality = Key<Double>("jpegQuality", default: 0.9)
    static let lastSaveDirectory = Key<String?>("lastSaveDirectory", default: nil)
    static let defaultAnnotationColor = Key<String>("defaultAnnotationColor", default: "#FF0000")
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter "AnnotationTests|CaptureStateTests"`
Expected: PASS

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Models/ LightShotCloneTests/AnnotationTests.swift LightShotCloneTests/CaptureStateTests.swift
git commit -m "feat: add data models for Annotation, AnnotationTool, CaptureState, and AppSettings"
```

---

## Task 5: Overlay Window Controller

**Files:**
- Create: `LightShotClone/LightShotClone/Views/Overlay/OverlayWindowController.swift`
- Create: `LightShotClone/LightShotClone/Views/Overlay/DimmingShape.swift`
- Create: `LightShotClone/LightShotClone/Views/Overlay/SelectionOverlayView.swift`
- Create: `LightShotClone/LightShotClone/ViewModels/CaptureViewModel.swift`

**Step 1: Write DimmingShape**

```swift
// LightShotClone/LightShotClone/Views/Overlay/DimmingShape.swift
import SwiftUI

/// A shape that fills the entire rect with a rectangular cutout (hole)
/// Must be rendered with eoFill for the cutout to be transparent
struct DimmingShape: Shape {
    let cutout: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let cutout = cutout {
            path.addRect(cutout)
        }
        return path
    }
}
```

**Step 2: Write CaptureViewModel**

```swift
// LightShotClone/LightShotClone/ViewModels/CaptureViewModel.swift
import SwiftUI
import Combine

final class CaptureViewModel: ObservableObject {
    @Published var state: CaptureState = .idle
    @Published var selectionRect: CGRect? = nil
    @Published var dragStart: CGPoint? = nil
    @Published var dragCurrent: CGPoint? = nil

    // Selection resize handles
    @Published var isResizing = false
    @Published var resizeHandle: ResizeHandle? = nil

    // Screenshot data
    @Published var capturedImage: CGImage? = nil

    // Callbacks
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    enum ResizeHandle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    /// Start a new selection drag
    func beginDrag(at point: CGPoint) {
        // Check if we're clicking a resize handle
        if let rect = selectionRect, let handle = hitTestHandle(at: point, in: rect) {
            isResizing = true
            resizeHandle = handle
            dragStart = point
            return
        }

        // Check if clicking inside existing selection (to move it)
        if let rect = selectionRect, rect.contains(point) {
            isResizing = true
            resizeHandle = nil // nil = moving
            dragStart = point
            return
        }

        // New selection
        dragStart = point
        dragCurrent = point
        selectionRect = nil
        state = .selecting(origin: point)
    }

    /// Update during drag
    func updateDrag(to point: CGPoint) {
        if isResizing {
            updateResize(to: point)
            return
        }

        dragCurrent = point
        if let start = dragStart {
            selectionRect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
        }
    }

    /// End drag
    func endDrag(at point: CGPoint) {
        if isResizing {
            isResizing = false
            resizeHandle = nil
            dragStart = nil
            return
        }

        updateDrag(to: point)
        dragStart = nil
        dragCurrent = nil

        if let rect = selectionRect, rect.width > 5, rect.height > 5 {
            state = .selected(rect: rect)
            onSelectionComplete?(rect)
        }
    }

    /// Cancel the capture
    func cancel() {
        state = .idle
        selectionRect = nil
        dragStart = nil
        dragCurrent = nil
        onCancel?()
    }

    /// Move selection with arrow keys (pixel-perfect adjustment)
    func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard var rect = selectionRect else { return }
        rect.origin.x += dx
        rect.origin.y += dy
        selectionRect = rect
    }

    // MARK: - Resize Handles

    private let handleSize: CGFloat = 8

    func handleRect(for handle: ResizeHandle, in selectionRect: CGRect) -> CGRect {
        let hs = handleSize
        let r = selectionRect
        switch handle {
        case .topLeft:     return CGRect(x: r.minX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .topRight:    return CGRect(x: r.maxX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .bottomLeft:  return CGRect(x: r.minX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .bottomRight: return CGRect(x: r.maxX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .top:         return CGRect(x: r.midX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .bottom:      return CGRect(x: r.midX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .left:        return CGRect(x: r.minX - hs/2, y: r.midY - hs/2, width: hs, height: hs)
        case .right:       return CGRect(x: r.maxX - hs/2, y: r.midY - hs/2, width: hs, height: hs)
        }
    }

    private func hitTestHandle(at point: CGPoint, in rect: CGRect) -> ResizeHandle? {
        for handle in ResizeHandle.allCases {
            let hr = handleRect(for: handle, in: rect).insetBy(dx: -4, dy: -4)
            if hr.contains(point) { return handle }
        }
        return nil
    }

    private func updateResize(to point: CGPoint) {
        guard var rect = selectionRect, let handle = resizeHandle else {
            // Moving the entire selection
            if let start = dragStart, let currentRect = selectionRect {
                let dx = point.x - start.x
                let dy = point.y - start.y
                selectionRect = currentRect.offsetBy(dx: dx, dy: dy)
                dragStart = point
            }
            return
        }

        switch handle {
        case .topLeft:
            rect = CGRect(x: point.x, y: point.y, width: rect.maxX - point.x, height: rect.maxY - point.y)
        case .topRight:
            rect = CGRect(x: rect.minX, y: point.y, width: point.x - rect.minX, height: rect.maxY - point.y)
        case .bottomLeft:
            rect = CGRect(x: point.x, y: rect.minY, width: rect.maxX - point.x, height: point.y - rect.minY)
        case .bottomRight:
            rect = CGRect(x: rect.minX, y: rect.minY, width: point.x - rect.minX, height: point.y - rect.minY)
        case .top:
            rect = CGRect(x: rect.minX, y: point.y, width: rect.width, height: rect.maxY - point.y)
        case .bottom:
            rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: point.y - rect.minY)
        case .left:
            rect = CGRect(x: point.x, y: rect.minY, width: rect.maxX - point.x, height: rect.height)
        case .right:
            rect = CGRect(x: rect.minX, y: rect.minY, width: point.x - rect.minX, height: rect.height)
        }

        // Normalize to prevent negative sizes
        selectionRect = CGRect(
            x: min(rect.origin.x, rect.origin.x + rect.width),
            y: min(rect.origin.y, rect.origin.y + rect.height),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }
}
```

**Step 3: Write SelectionOverlayView**

```swift
// LightShotClone/LightShotClone/Views/Overlay/SelectionOverlayView.swift
import SwiftUI

struct SelectionOverlayView: View {
    @ObservedObject var viewModel: CaptureViewModel
    let screenFrame: CGRect

    var body: some View {
        ZStack {
            // Dimming overlay with cutout
            DimmingShape(cutout: viewModel.selectionRect)
                .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            // Selection border and resize handles
            if let rect = viewModel.selectionRect {
                // Selection border
                Rectangle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                // Resize handles (8 handles)
                ForEach(CaptureViewModel.ResizeHandle.allCases, id: \.self) { handle in
                    let hr = viewModel.handleRect(for: handle, in: rect)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: hr.width, height: hr.height)
                        .position(x: hr.midX, y: hr.midY)
                        .allowsHitTesting(false)
                }

                // Dimension label (above selection, left-aligned)
                Text("\(Int(rect.width)) x \(Int(rect.height))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    .position(
                        x: rect.minX + 40,
                        y: max(rect.minY - 14, 14)
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    if viewModel.dragStart == nil {
                        viewModel.beginDrag(at: value.startLocation)
                    }
                    viewModel.updateDrag(to: value.location)
                }
                .onEnded { value in
                    viewModel.endDrag(at: value.location)
                }
        )
        .onKeyPress(.escape) {
            viewModel.cancel()
            return .handled
        }
        .onKeyPress(.upArrow) { viewModel.nudgeSelection(dx: 0, dy: -1); return .handled }
        .onKeyPress(.downArrow) { viewModel.nudgeSelection(dx: 0, dy: 1); return .handled }
        .onKeyPress(.leftArrow) { viewModel.nudgeSelection(dx: -1, dy: 0); return .handled }
        .onKeyPress(.rightArrow) { viewModel.nudgeSelection(dx: 1, dy: 0); return .handled }
    }
}

// Make ResizeHandle conform to CaseIterable (it already does in ViewModel)
extension CaptureViewModel.ResizeHandle: Hashable {}
```

**Step 4: Write OverlayWindowController**

```swift
// LightShotClone/LightShotClone/Views/Overlay/OverlayWindowController.swift
import AppKit
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private let viewModel = CaptureViewModel()
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    func showOverlays() {
        viewModel.onCancel = { [weak self] in
            self?.dismissOverlays()
            self?.onCancel?()
        }

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let overlayView = SelectionOverlayView(
                viewModel: viewModel,
                screenFrame: screen.frame
            ).frame(width: screen.frame.width, height: screen.frame.height)

            window.contentView = NSHostingView(rootView: overlayView)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        // Set cursor to crosshair
        NSCursor.crosshair.push()

        // Listen for selection completion
        viewModel.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            // Find which screen the selection is on
            let screen = NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main ?? NSScreen.screens[0]
            self.onSelectionComplete?(rect, screen)
        }
    }

    func dismissOverlays() {
        NSCursor.pop()
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}
```

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Views/Overlay/ LightShotClone/LightShotClone/ViewModels/CaptureViewModel.swift
git commit -m "feat: add overlay window system with selection, dimming, resize handles, and dimension display"
```

---

## Task 6: Annotation ViewModel and Renderer

**Files:**
- Create: `LightShotClone/LightShotClone/ViewModels/AnnotationViewModel.swift`
- Create: `LightShotClone/LightShotClone/Views/Annotation/AnnotationRenderer.swift`
- Create: `LightShotClone/LightShotClone/Views/Annotation/AnnotationCanvasView.swift`

**Step 1: Write AnnotationViewModel**

```swift
// LightShotClone/LightShotClone/ViewModels/AnnotationViewModel.swift
import SwiftUI

final class AnnotationViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentAnnotation: Annotation? = nil
    @Published var selectedTool: AnnotationTool? = nil
    @Published var currentColor: Color = .red
    @Published var currentLineWidth: CGFloat = 2
    @Published var currentFontSize: CGFloat = 16
    @Published var isEditingText = false
    @Published var textEditPosition: CGPoint = .zero
    @Published var textEditContent: String = ""

    private var undoStack: [[Annotation]] = []

    // MARK: - Tool Selection

    func selectTool(_ tool: AnnotationTool) {
        if selectedTool == tool {
            selectedTool = nil // Toggle off
        } else {
            selectedTool = tool
        }
        commitTextIfNeeded()
    }

    // MARK: - Drawing

    func beginStroke(at point: CGPoint) {
        guard let tool = selectedTool else { return }

        if tool == .text {
            commitTextIfNeeded()
            isEditingText = true
            textEditPosition = point
            textEditContent = ""
            return
        }

        let color: Color = (tool == .marker) ? .yellow.opacity(0.4) : currentColor
        let lineWidth: CGFloat = (tool == .marker) ? max(currentLineWidth * 5, 20) : currentLineWidth

        var annotation = Annotation(
            tool: tool,
            startPoint: point,
            endPoint: point,
            color: color,
            lineWidth: lineWidth
        )

        if tool == .pen || tool == .marker {
            annotation.freehandPoints = [point]
        }

        currentAnnotation = annotation
    }

    func continueStroke(to point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        if annotation.tool == .pen || annotation.tool == .marker {
            annotation.freehandPoints.append(point)
        }
        annotation.endPoint = point
        currentAnnotation = annotation
    }

    func endStroke(at point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        if annotation.tool == .pen || annotation.tool == .marker {
            annotation.freehandPoints.append(point)
        }
        annotation.endPoint = point

        undoStack.append(annotations)
        annotations.append(annotation)
        currentAnnotation = nil
    }

    // MARK: - Text

    func commitTextIfNeeded() {
        guard isEditingText, !textEditContent.isEmpty else {
            isEditingText = false
            return
        }

        var annotation = Annotation(
            tool: .text,
            startPoint: textEditPosition,
            endPoint: textEditPosition,
            color: currentColor,
            lineWidth: 1,
            text: textEditContent,
            fontSize: currentFontSize
        )
        annotation.text = textEditContent

        undoStack.append(annotations)
        annotations.append(annotation)
        isEditingText = false
        textEditContent = ""
    }

    // MARK: - Line Width / Font Size (scroll wheel)

    func adjustSize(delta: CGFloat) {
        if selectedTool == .text || isEditingText {
            currentFontSize = max(8, min(72, currentFontSize + delta))
        } else {
            currentLineWidth = max(1, min(20, currentLineWidth + delta))
        }
    }

    // MARK: - Undo

    func undo() {
        if let previous = undoStack.popLast() {
            annotations = previous
        }
    }

    /// Render all annotations onto a CGImage and return the composited result
    func renderAnnotations(onto image: CGImage, selectionRect: CGRect) -> CGImage? {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the base image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw annotations using NSGraphicsContext
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        for annotation in annotations {
            AnnotationRenderer.draw(annotation, in: context, canvasSize: CGSize(width: width, height: height))
        }

        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage()
    }
}
```

**Step 2: Write AnnotationRenderer**

```swift
// LightShotClone/LightShotClone/Views/Annotation/AnnotationRenderer.swift
import AppKit
import SwiftUI

enum AnnotationRenderer {
    /// Draw an annotation into a CGContext (for final rendering)
    static func draw(_ annotation: Annotation, in context: CGContext, canvasSize: CGSize) {
        let nsColor = NSColor(annotation.color)
        context.setStrokeColor(nsColor.cgColor)
        context.setFillColor(nsColor.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .pen, .marker:
            guard annotation.freehandPoints.count > 1 else { return }
            context.beginPath()
            context.move(to: annotation.freehandPoints[0])
            for point in annotation.freehandPoints.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()

        case .line:
            context.beginPath()
            context.move(to: annotation.startPoint)
            context.addLine(to: annotation.endPoint)
            context.strokePath()

        case .arrow:
            drawArrow(from: annotation.startPoint, to: annotation.endPoint,
                      lineWidth: annotation.lineWidth, in: context)

        case .rectangle:
            let rect = annotation.boundingRect
            context.stroke(rect)

        case .text:
            let font = NSFont.systemFont(ofSize: annotation.fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            let string = NSAttributedString(string: annotation.text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(string)
            context.textPosition = annotation.startPoint
            CTLineDraw(line, context)
        }
    }

    /// Draw an annotation into a SwiftUI GraphicsContext (for live preview)
    static func draw(_ annotation: Annotation, in context: inout GraphicsContext) {
        switch annotation.tool {
        case .pen, .marker:
            guard annotation.freehandPoints.count > 1 else { return }
            var path = Path()
            path.move(to: annotation.freehandPoints[0])
            for point in annotation.freehandPoints.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(annotation.color),
                style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round)
            )

        case .line:
            var path = Path()
            path.move(to: annotation.startPoint)
            path.addLine(to: annotation.endPoint)
            context.stroke(path, with: .color(annotation.color),
                           style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round))

        case .arrow:
            drawArrowSwiftUI(from: annotation.startPoint, to: annotation.endPoint,
                             color: annotation.color, lineWidth: annotation.lineWidth, in: &context)

        case .rectangle:
            let rect = annotation.boundingRect
            context.stroke(Path(rect), with: .color(annotation.color),
                           style: StrokeStyle(lineWidth: annotation.lineWidth))

        case .text:
            let text = Text(annotation.text)
                .font(.system(size: annotation.fontSize))
                .foregroundColor(annotation.color)
            context.draw(context.resolve(text), at: annotation.startPoint, anchor: .topLeading)
        }
    }

    // MARK: - Arrow Drawing

    private static func drawArrow(from start: CGPoint, to end: CGPoint,
                                   lineWidth: CGFloat, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(15, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        // Shaft
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Arrowhead
        let tip1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.beginPath()
        context.move(to: tip1)
        context.addLine(to: end)
        context.addLine(to: tip2)
        context.strokePath()
    }

    private static func drawArrowSwiftUI(from start: CGPoint, to end: CGPoint,
                                          color: Color, lineWidth: CGFloat,
                                          in context: inout GraphicsContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(15, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        var path = Path()
        // Shaft
        path.move(to: start)
        path.addLine(to: end)
        // Arrowhead
        path.move(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        path.addLine(to: end)
        path.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))

        context.stroke(path, with: .color(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}
```

**Step 3: Write AnnotationCanvasView**

```swift
// LightShotClone/LightShotClone/Views/Annotation/AnnotationCanvasView.swift
import SwiftUI

struct AnnotationCanvasView: View {
    @ObservedObject var viewModel: AnnotationViewModel
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Canvas for rendering completed + in-progress annotations
            Canvas { context, size in
                for annotation in viewModel.annotations {
                    AnnotationRenderer.draw(annotation, in: &context)
                }
                if let current = viewModel.currentAnnotation {
                    AnnotationRenderer.draw(current, in: &context)
                }
            }
            .allowsHitTesting(false)

            // Gesture layer for drawing
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .local)
                        .onChanged { value in
                            if viewModel.currentAnnotation == nil {
                                viewModel.beginStroke(at: value.startLocation)
                            }
                            viewModel.continueStroke(to: value.location)
                        }
                        .onEnded { value in
                            viewModel.endStroke(at: value.location)
                        }
                )

            // Text editing field
            if viewModel.isEditingText {
                TextField("", text: $viewModel.textEditContent)
                    .textFieldStyle(.plain)
                    .font(.system(size: viewModel.currentFontSize))
                    .foregroundColor(viewModel.currentColor)
                    .frame(minWidth: 100, maxWidth: 300)
                    .position(viewModel.textEditPosition)
                    .onSubmit {
                        viewModel.commitTextIfNeeded()
                    }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .onScrollWheel { delta in
            viewModel.adjustSize(delta: delta)
        }
    }
}

// MARK: - Scroll Wheel Modifier

struct ScrollWheelModifier: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content.background(
            ScrollWheelReceiver(onScroll: onScroll)
        )
    }
}

struct ScrollWheelReceiver: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY > 0 ? CGFloat(1) : CGFloat(-1)
        onScroll?(delta)
    }
}

extension View {
    func onScrollWheel(_ handler: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(onScroll: handler))
    }
}
```

**Step 4: Commit**

```bash
git add LightShotClone/LightShotClone/ViewModels/AnnotationViewModel.swift \
        LightShotClone/LightShotClone/Views/Annotation/
git commit -m "feat: add annotation system with Canvas rendering, all tool types, undo, and scroll-wheel sizing"
```

---

## Task 7: Floating Toolbars (Editing + Action)

**Files:**
- Create: `LightShotClone/LightShotClone/Views/Toolbar/EditingToolbarController.swift`
- Create: `LightShotClone/LightShotClone/Views/Toolbar/EditingToolbarView.swift`
- Create: `LightShotClone/LightShotClone/Views/Toolbar/ActionToolbarController.swift`
- Create: `LightShotClone/LightShotClone/Views/Toolbar/ActionToolbarView.swift`
- Create: `LightShotClone/LightShotClone/Views/ColorPicker/ColorPickerPopover.swift`

**Step 1: Write EditingToolbarView (vertical, right side)**

```swift
// LightShotClone/LightShotClone/Views/Toolbar/EditingToolbarView.swift
import SwiftUI

struct EditingToolbarView: View {
    @ObservedObject var annotationVM: AnnotationViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Drawing tools
            ForEach(AnnotationTool.allCases) { tool in
                ToolButton(
                    systemImage: tool.systemImage,
                    isSelected: annotationVM.selectedTool == tool,
                    tooltip: tool.displayName
                ) {
                    annotationVM.selectTool(tool)
                }
            }

            // Color picker
            ColorButton(color: annotationVM.currentColor) {
                // Toggle color picker popover
            }
            .popover(isPresented: .constant(false)) {
                ColorPickerPopover(selectedColor: $annotationVM.currentColor)
            }

            Divider()
                .frame(width: 24)
                .padding(.vertical, 2)

            // Undo
            ToolButton(
                systemImage: "arrow.uturn.backward",
                isSelected: false,
                tooltip: "Undo (Cmd+Z)"
            ) {
                annotationVM.undo()
            }

            // Close
            ToolButton(
                systemImage: "xmark",
                isSelected: false,
                tooltip: "Close (Esc)"
            ) {
                onClose()
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
}

struct ToolButton: View {
    let systemImage: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ColorButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("Color")
    }
}
```

**Step 2: Write ActionToolbarView (horizontal, bottom)**

```swift
// LightShotClone/LightShotClone/Views/Toolbar/ActionToolbarView.swift
import SwiftUI

struct ActionToolbarView: View {
    var onUpload: () -> Void
    var onSearchSimilar: () -> Void
    var onPrint: () -> Void
    var onCopy: () -> Void
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ActionButton(systemImage: "icloud.and.arrow.up", tooltip: "Upload (Cmd+D)", action: onUpload)
            ActionButton(systemImage: "magnifyingglass", tooltip: "Search Similar Images", action: onSearchSimilar)
            ActionButton(systemImage: "printer", tooltip: "Print (Cmd+P)", action: onPrint)
            ActionButton(systemImage: "doc.on.clipboard", tooltip: "Copy (Cmd+C)", action: onCopy)
            ActionButton(systemImage: "square.and.arrow.down", tooltip: "Save (Cmd+S)", action: onSave)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
}

struct ActionButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
```

**Step 3: Write ColorPickerPopover**

```swift
// LightShotClone/LightShotClone/Views/ColorPicker/ColorPickerPopover.swift
import SwiftUI

struct ColorPickerPopover: View {
    @Binding var selectedColor: Color

    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple,
        .pink, .brown, .cyan, .mint, .indigo, .teal,
        .white, .gray, .black
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Color")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Preset color grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6), spacing: 6) {
                ForEach(presetColors, id: \.self) { color in
                    ColorSwatch(color: color, isSelected: selectedColor == color) {
                        selectedColor = color
                    }
                }
            }

            Divider()

            // System color picker for custom colors
            ColorPicker("Custom Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(12)
        .frame(width: 180)
    }
}

struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

**Step 4: Write Toolbar Controllers (NSPanel wrappers)**

```swift
// LightShotClone/LightShotClone/Views/Toolbar/EditingToolbarController.swift
import AppKit
import SwiftUI

final class EditingToolbarController {
    private var panel: NSPanel?
    let annotationVM: AnnotationViewModel

    init(annotationVM: AnnotationViewModel) {
        self.annotationVM = annotationVM
    }

    /// Show the vertical editing toolbar to the right of the selection
    func show(near selectionRect: NSRect, onClose: @escaping () -> Void) {
        let toolbarWidth: CGFloat = 40
        let toolbarHeight: CGFloat = 320
        let margin: CGFloat = 8

        // Position to the right of the selection
        var x = selectionRect.maxX + margin
        let y = selectionRect.maxY - toolbarHeight

        // If off-screen right, move to the left side
        let screenMaxX = NSScreen.main?.frame.maxX ?? 1920
        if x + toolbarWidth > screenMaxX {
            x = selectionRect.minX - toolbarWidth - margin
        }

        let frame = NSRect(x: x, y: max(y, 0), width: toolbarWidth, height: toolbarHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let view = EditingToolbarView(annotationVM: annotationVM, onClose: onClose)
        panel.contentView = NSHostingView(rootView: view)

        panel.orderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    func reposition(near selectionRect: NSRect) {
        guard let panel = panel else { return }
        let margin: CGFloat = 8
        let x = selectionRect.maxX + margin
        let y = selectionRect.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, 0)))
    }
}
```

```swift
// LightShotClone/LightShotClone/Views/Toolbar/ActionToolbarController.swift
import AppKit
import SwiftUI

final class ActionToolbarController {
    private var panel: NSPanel?

    /// Show the horizontal action toolbar below the selection
    func show(near selectionRect: NSRect,
              onUpload: @escaping () -> Void,
              onSearchSimilar: @escaping () -> Void,
              onPrint: @escaping () -> Void,
              onCopy: @escaping () -> Void,
              onSave: @escaping () -> Void) {
        let toolbarWidth: CGFloat = 200
        let toolbarHeight: CGFloat = 40
        let margin: CGFloat = 8

        // Position below the selection, aligned to the right
        let x = selectionRect.maxX - toolbarWidth
        var y = selectionRect.minY - toolbarHeight - margin

        // If off-screen bottom, move above the selection
        if y < 0 {
            y = selectionRect.maxY + margin
        }

        let frame = NSRect(x: max(x, 0), y: y, width: toolbarWidth, height: toolbarHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let view = ActionToolbarView(
            onUpload: onUpload,
            onSearchSimilar: onSearchSimilar,
            onPrint: onPrint,
            onCopy: onCopy,
            onSave: onSave
        )
        panel.contentView = NSHostingView(rootView: view)

        panel.orderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    func reposition(near selectionRect: NSRect) {
        guard let panel = panel else { return }
        let margin: CGFloat = 8
        let x = selectionRect.maxX - panel.frame.width
        let y = selectionRect.minY - panel.frame.height - margin
        panel.setFrameOrigin(NSPoint(x: max(x, 0), y: y))
    }
}
```

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Views/Toolbar/ LightShotClone/LightShotClone/Views/ColorPicker/
git commit -m "feat: add floating editing toolbar, action toolbar, and color picker popover"
```

---

## Task 8: Action Services (Clipboard, File Save, Print)

**Files:**
- Create: `LightShotClone/LightShotClone/Services/ClipboardService.swift`
- Create: `LightShotClone/LightShotClone/Services/FileSaveService.swift`
- Create: `LightShotClone/LightShotClone/Services/PrintService.swift`
- Create: `LightShotCloneTests/ClipboardServiceTests.swift`
- Create: `LightShotCloneTests/FileSaveServiceTests.swift`

**Step 1: Write ClipboardService test**

```swift
// LightShotCloneTests/ClipboardServiceTests.swift
import XCTest
@testable import LightShotClone

final class ClipboardServiceTests: XCTestCase {
    func testCopyNSImageToClipboard() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        ClipboardService.copy(image)

        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue]))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ClipboardServiceTests`
Expected: FAIL

**Step 3: Write services**

```swift
// LightShotClone/LightShotClone/Services/ClipboardService.swift
import AppKit

enum ClipboardService {
    /// Copy an NSImage to the system clipboard
    static func copy(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    /// Copy a CGImage to the system clipboard
    static func copy(_ cgImage: CGImage) {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        copy(nsImage)
    }

    /// Copy a URL string to the clipboard
    static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

```swift
// LightShotClone/LightShotClone/Services/FileSaveService.swift
import AppKit
import UniformTypeIdentifiers

enum FileSaveService {
    /// Show a save dialog and save the image
    @MainActor
    static func saveWithDialog(_ image: NSImage) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp]
        panel.nameFieldStringValue = "Screenshot \(timestamp()).png"
        panel.canCreateDirectories = true

        // Restore last save directory
        if let lastDir = UserDefaults.standard.string(forKey: "lastSaveDirectory") {
            panel.directoryURL = URL(fileURLWithPath: lastDir)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        // Remember directory
        UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: "lastSaveDirectory")

        let format = imageFormat(for: url)
        return save(image, to: url, format: format) ? url : nil
    }

    /// Save an image to a specific URL
    static func save(_ image: NSImage, to url: URL, format: NSBitmapImageRep.FileType = .png) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else { return false }

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            let quality = UserDefaults.standard.double(forKey: "jpegQuality")
            properties[.compressionFactor] = quality > 0 ? quality : 0.9
        }

        guard let data = bitmapRep.representation(using: format, properties: properties)
        else { return false }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func timestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return df.string(from: Date())
    }

    private static func imageFormat(for url: URL) -> NSBitmapImageRep.FileType {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "bmp": return .bmp
        case "tiff", "tif": return .tiff
        default: return .png
        }
    }
}
```

```swift
// LightShotClone/LightShotClone/Services/PrintService.swift
import AppKit

enum PrintService {
    /// Print an NSImage using the system print dialog
    @MainActor
    static func print(_ image: NSImage) {
        let imageView = NSImageView(frame: NSRect(
            origin: .zero,
            size: image.size
        ))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown

        let printOperation = NSPrintOperation(view: imageView)
        printOperation.printInfo.isHorizontallyCentered = true
        printOperation.printInfo.isVerticallyCentered = true
        printOperation.runModal(for: NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter ClipboardServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Services/ClipboardService.swift \
        LightShotClone/LightShotClone/Services/FileSaveService.swift \
        LightShotClone/LightShotClone/Services/PrintService.swift \
        LightShotCloneTests/ClipboardServiceTests.swift
git commit -m "feat: add ClipboardService, FileSaveService, and PrintService"
```

---

## Task 9: Image Upload Service (Imgur API)

**Files:**
- Create: `LightShotClone/LightShotClone/Services/ImageUploadService.swift`

**Step 1: Write ImageUploadService**

```swift
// LightShotClone/LightShotClone/Services/ImageUploadService.swift
import AppKit
import Foundation

struct ImgurResponse: Codable {
    let data: ImgurImageData
    let success: Bool
    let status: Int
}

struct ImgurImageData: Codable {
    let id: String
    let link: String
    let deletehash: String?
}

enum ImageUploadError: LocalizedError {
    case imageConversionFailed
    case uploadFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image for upload"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .invalidResponse: return "Invalid server response"
        }
    }
}

enum ImageUploadService {
    // Anonymous upload Client ID -- users should register their own at https://api.imgur.com
    private static let imgurClientID = "YOUR_IMGUR_CLIENT_ID"

    /// Upload an NSImage to Imgur and return the direct link
    static func uploadToImgur(_ image: NSImage) async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            throw ImageUploadError.imageConversionFailed
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.imgur.com/3/image")!)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(imgurClientID)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(pngData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImageUploadError.uploadFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoded = try JSONDecoder().decode(ImgurResponse.self, from: data)
        guard decoded.success else {
            throw ImageUploadError.uploadFailed("API returned failure")
        }

        return decoded.data.link
    }

    /// Open Google reverse image search with the uploaded URL
    static func searchSimilarImages(imageURL: String) {
        let searchURL = "https://www.google.com/searchbyimage?image_url=\(imageURL)"
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Alternative: search by uploading the image data directly via Google Lens
    static func searchSimilarImages(image: NSImage) async {
        // Upload first, then search
        if let link = try? await uploadToImgur(image) {
            searchSimilarImages(imageURL: link)
        }
    }
}
```

**Step 2: Commit**

```bash
git add LightShotClone/LightShotClone/Services/ImageUploadService.swift
git commit -m "feat: add ImageUploadService with Imgur API integration and Google image search"
```

---

## Task 10: Wire Everything Together - Main Capture Flow

**Files:**
- Modify: `LightShotClone/LightShotClone/App/AppDelegate.swift`
- Modify: `LightShotClone/LightShotClone/App/LightShotCloneApp.swift`

**Step 1: Rewrite AppDelegate with full capture orchestration**

```swift
// LightShotClone/LightShotClone/App/AppDelegate.swift
import AppKit
import KeyboardShortcuts
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var editingToolbar: EditingToolbarController?
    private var actionToolbar: ActionToolbarController?
    private var annotationVM = AnnotationViewModel()
    private var annotationWindow: NSWindow?

    // The full-screen capture taken before showing the overlay
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
            // 1. Capture the screen first (before showing overlay)
            guard let displays = try? await ScreenCaptureService.availableDisplays(),
                  let display = displays.first else { return }
            screenCapture = try? await ScreenCaptureService.captureFullScreen(display: display)

            // 2. Show the overlay for area selection
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

    // MARK: - Selection Complete -> Show Toolbars

    private func onSelectionComplete(rect: CGRect, screen: NSScreen) {
        currentSelectionRect = rect
        currentScreen = screen

        // Show annotation canvas over the selection
        showAnnotationCanvas(rect: rect, screen: screen)

        // Show editing toolbar (right side)
        let editToolbar = EditingToolbarController(annotationVM: annotationVM)
        editToolbar.show(near: rect, onClose: { [weak self] in
            self?.dismissAll()
        })
        editingToolbar = editToolbar

        // Show action toolbar (bottom)
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

    // MARK: - Actions

    private func getFinalImage() -> NSImage? {
        guard let capture = screenCapture, let rect = currentSelectionRect else { return nil }

        // Crop the capture to the selection rect (accounting for Retina)
        let scale = currentScreen?.backingScaleFactor ?? 2.0
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped = capture.cropping(to: scaledRect) else { return nil }

        // Render annotations onto the cropped image
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
                    // Show notification
                    showNotification(title: "Uploaded!", body: "Link copied to clipboard: \(link)")
                    dismissAll()
                }
            } catch {
                await MainActor.run {
                    showNotification(title: "Upload Failed", body: error.localizedDescription)
                }
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
            PrintService.print(image)
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
                    showNotification(title: "Uploaded!", body: link)
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

    // MARK: - Notifications

    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Dismiss

    private func dismissAll() {
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
```

**Step 2: Update LightShotCloneApp with full menu**

```swift
// LightShotClone/LightShotClone/App/LightShotCloneApp.swift
import SwiftUI
import KeyboardShortcuts

@main
struct LightShotCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LightShot", systemImage: "camera.viewfinder") {
            Button("Capture Region") {
                appDelegate.startRegionCapture()
            }

            Divider()

            Button("Preferences...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit LightShot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}
```

**Step 3: Verify it compiles**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add LightShotClone/LightShotClone/App/
git commit -m "feat: wire up complete capture flow - overlay, selection, annotation, toolbars, and all actions"
```

---

## Task 11: Settings Views

**Files:**
- Create: `LightShotClone/LightShotClone/Views/Settings/SettingsView.swift`
- Create: `LightShotClone/LightShotClone/Views/Settings/GeneralSettingsView.swift`
- Create: `LightShotClone/LightShotClone/Views/Settings/HotkeySettingsView.swift`
- Create: `LightShotClone/LightShotClone/Views/Settings/FormatSettingsView.swift`

**Step 1: Write SettingsView (TabView)**

```swift
// LightShotClone/LightShotClone/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            FormatSettingsView()
                .tabItem {
                    Label("Formats", systemImage: "doc")
                }
        }
        .frame(width: 450, height: 300)
    }
}
```

**Step 2: Write GeneralSettingsView**

```swift
// LightShotClone/LightShotClone/Views/Settings/GeneralSettingsView.swift
import SwiftUI
import Defaults
import LaunchAtLogin

struct GeneralSettingsView: View {
    @Default(.autoCopyLinkAfterUpload) var autoCopyLink
    @Default(.autoCloseUploadWindow) var autoCloseUpload
    @Default(.showNotifications) var showNotifications
    @Default(.keepSelectionPosition) var keepSelection
    @Default(.captureCursor) var captureCursor

    var body: some View {
        Form {
            Toggle("Automatically copy link after uploading", isOn: $autoCopyLink)
            Toggle("Automatically close upload window", isOn: $autoCloseUpload)
            Toggle("Show notifications about copying/saving", isOn: $showNotifications)
            Toggle("Keep selected area position", isOn: $keepSelection)
            Toggle("Capture cursor on screenshot", isOn: $captureCursor)

            Divider()

            LaunchAtLogin.Toggle("Launch at login")
        }
        .padding(20)
    }
}
```

**Step 3: Write HotkeySettingsView**

```swift
// LightShotClone/LightShotClone/Views/Settings/HotkeySettingsView.swift
import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
            KeyboardShortcuts.Recorder("Instant Save Full Screen:", name: .captureFullScreen)
            KeyboardShortcuts.Recorder("Instant Upload Full Screen:", name: .instantUploadFullScreen)
        }
        .padding(20)
    }
}
```

**Step 4: Write FormatSettingsView**

```swift
// LightShotClone/LightShotClone/Views/Settings/FormatSettingsView.swift
import SwiftUI
import Defaults

struct FormatSettingsView: View {
    @Default(.uploadFormat) var uploadFormat
    @Default(.jpegQuality) var jpegQuality

    var body: some View {
        Form {
            Picker("Upload format:", selection: $uploadFormat) {
                Text("PNG").tag("png")
                Text("JPEG").tag("jpeg")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if uploadFormat == "jpeg" {
                HStack {
                    Text("JPEG Quality:")
                    Slider(value: $jpegQuality, in: 0.5...1.0, step: 0.1)
                    Text("\(Int(jpegQuality * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .padding(20)
    }
}
```

**Step 5: Commit**

```bash
git add LightShotClone/LightShotClone/Views/Settings/
git commit -m "feat: add Settings views with General, Hotkey, and Format tabs"
```

---

## Task 12: Keyboard Shortcuts During Capture

**Files:**
- Modify: `LightShotClone/LightShotClone/Views/Overlay/SelectionOverlayView.swift`
- Modify: `LightShotClone/LightShotClone/App/AppDelegate.swift`

**Step 1: Add keyboard shortcut handling for annotation mode**

Add a local keyboard event monitor in AppDelegate that handles shortcuts during capture:

```swift
// Add to AppDelegate.swift - in onSelectionComplete() after showing toolbars:

private var localKeyMonitor: Any?
private var localFlagsMonitor: Any?

// Call this after selection is complete:
private func installKeyMonitor() {
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self = self else { return event }

        let cmd = event.modifierFlags.contains(.command)

        switch event.keyCode {
        case 53: // Escape
            self.dismissAll()
            return nil
        default: break
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
                // Select all = maximize selection to full screen
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
    if let monitor = localFlagsMonitor {
        NSEvent.removeMonitor(monitor)
        localFlagsMonitor = nil
    }
}
```

**Step 2: Call installKeyMonitor in onSelectionComplete and removeKeyMonitor in dismissAll**

Add `installKeyMonitor()` at the end of `onSelectionComplete()`.
Add `removeKeyMonitor()` at the start of `dismissAll()`.

**Step 3: Verify it compiles**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add LightShotClone/LightShotClone/App/AppDelegate.swift
git commit -m "feat: add keyboard shortcuts during capture (Cmd+C/S/D/P/Z/A, Esc)"
```

---

## Task 13: Final Polish and Build

**Files:**
- Create: `LightShotClone/LightShotClone/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `LightShotClone/Package.swift` (ensure all files are included)

**Step 1: Create Assets catalog structure**

```json
// Assets.xcassets/AppIcon.appiconset/Contents.json
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "16x16" },
    { "idiom": "mac", "scale": "2x", "size": "16x16" },
    { "idiom": "mac", "scale": "1x", "size": "32x32" },
    { "idiom": "mac", "scale": "2x", "size": "32x32" },
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

**Step 2: Full build and manual test**

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `swift run LightShotClone`
Manual test checklist:
- [ ] Menu bar icon appears (camera viewfinder)
- [ ] Clicking "Capture Region" shows overlay with dimming
- [ ] Click-drag creates selection with dimension display
- [ ] Resize handles appear and work (8 handles)
- [ ] Vertical toolbar appears right of selection (pen, line, arrow, rect, text, marker, color, undo, close)
- [ ] Horizontal toolbar appears below selection (upload, search, print, copy, save)
- [ ] Pen tool draws freehand
- [ ] Line tool draws straight lines
- [ ] Arrow tool draws arrows with arrowheads
- [ ] Rectangle tool draws rectangles
- [ ] Text tool places editable text
- [ ] Marker tool highlights with semi-transparent yellow
- [ ] Color picker works
- [ ] Undo reverts last annotation
- [ ] Cmd+C copies to clipboard
- [ ] Cmd+S opens save dialog
- [ ] Cmd+Z undoes
- [ ] Esc cancels capture
- [ ] Arrow keys nudge selection by 1px
- [ ] Scroll wheel changes line thickness / font size
- [ ] Settings window opens with 3 tabs
- [ ] Hotkey customization works

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: LightShot clone v1.0 - complete screenshot tool for macOS"
```

---

## Summary of All Tasks

| Task | Description | Est. Files |
|------|-------------|-----------|
| 1 | Project setup, SPM deps, minimal app skeleton | 4 |
| 2 | PermissionManager (screen recording + accessibility) | 2 |
| 3 | ScreenCaptureService, CoordinateConverter, MultiMonitorManager | 4 |
| 4 | Data models (Annotation, Tool, CaptureState, AppSettings) | 6 |
| 5 | Overlay window system (selection, dimming, resize, dimension label) | 4 |
| 6 | Annotation engine (ViewModel, Renderer, Canvas) | 3 |
| 7 | Floating toolbars (editing + action) and color picker | 5 |
| 8 | Action services (clipboard, file save, print) | 5 |
| 9 | Image upload service (Imgur API) | 1 |
| 10 | Wire everything together in AppDelegate | 2 |
| 11 | Settings views (General, Hotkeys, Formats) | 4 |
| 12 | Keyboard shortcuts during capture mode | 1 |
| 13 | Final polish, assets, full build + manual test | 2 |

**Total: ~43 files, 13 tasks**

---

Plan complete and saved to `docs/plans/2026-02-28-lightshot-clone.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
