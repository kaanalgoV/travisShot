import Defaults
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureRegion = Self("captureRegion", default: .init(.backtick, modifiers: [.command]))
    static let captureFullScreen = Self("captureFullScreen")
    static let instantUploadFullScreen = Self("instantUploadFullScreen")
}

extension Defaults.Keys {
    /// Migration flag to force-reset global hotkeys to correct defaults
    static let hotkeyMigrationV2 = Key<Bool>("hotkeyMigrationV2", default: false)

    static let autoCopyLinkAfterUpload = Key<Bool>("autoCopyLinkAfterUpload", default: true)
    static let showNotifications = Key<Bool>("showNotifications", default: true)
    static let keepSelectionPosition = Key<Bool>("keepSelectionPosition", default: false)
    static let captureCursor = Key<Bool>("captureCursor", default: false)
    static let uploadFormat = Key<String>("uploadFormat", default: "png")
    static let jpegQuality = Key<Double>("jpegQuality", default: 0.9)
    static let lastSaveDirectory = Key<String?>("lastSaveDirectory", default: nil)
    static let quickSaveDirectory = Key<String>("quickSaveDirectory", default: "")
    static let defaultAnnotationColor = Key<String>("defaultAnnotationColor", default: "#FF0000")
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let imgurClientID = Key<String>("imgurClientID", default: "")

    // Tool shortcuts (single character, no modifier — active during capture)
    static let shortcutSelect = Key<String>("shortcutSelect", default: "v")
    static let shortcutPen = Key<String>("shortcutPen", default: "p")
    static let shortcutLine = Key<String>("shortcutLine", default: "l")
    static let shortcutArrow = Key<String>("shortcutArrow", default: "a")
    static let shortcutRectangle = Key<String>("shortcutRectangle", default: "r")
    static let shortcutText = Key<String>("shortcutText", default: "t")
    static let shortcutMarker = Key<String>("shortcutMarker", default: "m")
    static let shortcutNumber = Key<String>("shortcutNumber", default: "n")

    // Toggle shortcuts (single character, no modifier — active during capture)
    static let shortcutFreeze = Key<String>("shortcutFreeze", default: "f")
    static let shortcutClearAll = Key<String>("shortcutClearAll", default: "x")

    // Action shortcuts (character used with Cmd modifier — active during capture)
    static let shortcutCopy = Key<String>("shortcutCopy", default: "c")
    static let shortcutSave = Key<String>("shortcutSave", default: "s")
    static let shortcutUpload = Key<String>("shortcutUpload", default: "d")
    static let shortcutPrint = Key<String>("shortcutPrint", default: "p")
    static let shortcutUndo = Key<String>("shortcutUndo", default: "z")
}
