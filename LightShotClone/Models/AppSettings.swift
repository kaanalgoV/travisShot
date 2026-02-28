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
