import AppKit

final class OCROverlayView: NSView {
    private let textBlocks: [RecognizedTextBlock]
    private let imageSize: CGSize
    private let onCopyBlock: (String) -> Void
    private let onCopyAll: () -> Void
    private let onDismiss: () -> Void

    private var hoveredBlockIndex: Int?
    private var flashingBlockIndex: Int?
    private var flashTimer: Timer?

    private var copyAllButton: NSButton?
    private var dismissButton: NSButton?

    override var isFlipped: Bool { true }

    init(
        textBlocks: [RecognizedTextBlock],
        imageSize: CGSize,
        onCopyBlock: @escaping (String) -> Void,
        onCopyAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.textBlocks = textBlocks
        self.imageSize = imageSize
        self.onCopyBlock = onCopyBlock
        self.onCopyAll = onCopyAll
        self.onDismiss = onDismiss
        super.init(frame: .zero)

        setupButtons()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Setup

    private func setupButtons() {
        let copyAllBtn = NSButton(title: "Copy All", target: self, action: #selector(copyAllClicked))
        copyAllBtn.bezelStyle = .rounded
        copyAllBtn.controlSize = .small
        copyAllBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyAllBtn.autoresizingMask = []
        addSubview(copyAllBtn)
        copyAllButton = copyAllBtn

        let dismissBtn = NSButton(title: "✕", target: self, action: #selector(dismissClicked))
        dismissBtn.bezelStyle = .rounded
        dismissBtn.controlSize = .small
        dismissBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        dismissBtn.autoresizingMask = []
        addSubview(dismissBtn)
        dismissButton = dismissBtn
    }

    override func layout() {
        super.layout()
        let btnH: CGFloat = 22
        let btnW: CGFloat = 64
        let dismissW: CGFloat = 28
        let margin: CGFloat = 4

        copyAllButton?.frame = NSRect(
            x: bounds.maxX - btnW - dismissW - margin * 2,
            y: margin,
            width: btnW,
            height: btnH
        )
        dismissButton?.frame = NSRect(
            x: bounds.maxX - dismissW - margin,
            y: margin,
            width: dismissW,
            height: btnH
        )
    }

    // MARK: - Block Rects

    private func blockRect(for block: RecognizedTextBlock) -> NSRect {
        // Vision boundingBox: bottom-left origin, normalized 0-1
        // isFlipped=true means our view has top-left origin
        let x = block.boundingBox.origin.x * imageSize.width
        let y = (1.0 - block.boundingBox.origin.y - block.boundingBox.height) * imageSize.height
        let w = block.boundingBox.width * imageSize.width
        let h = block.boundingBox.height * imageSize.height
        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        for (index, block) in textBlocks.enumerated() {
            let rect = blockRect(for: block)
            let isHovered = hoveredBlockIndex == index
            let isFlashing = flashingBlockIndex == index

            // Fill
            if isFlashing {
                ctx.setFillColor(NSColor.systemGreen.withAlphaComponent(0.35).cgColor)
            } else if isHovered {
                ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.35).cgColor)
            } else {
                ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.15).cgColor)
            }
            ctx.fill(rect)

            // Border for hovered or flashing
            if isHovered || isFlashing {
                ctx.setStrokeColor(isFlashing
                    ? NSColor.systemGreen.cgColor
                    : NSColor.systemBlue.cgColor)
                ctx.setLineWidth(2)
                ctx.stroke(rect)
            }

            drawLabel(for: block, in: rect, context: ctx)
        }
    }

    private func drawLabel(for block: RecognizedTextBlock, in rect: NSRect, context: CGContext) {
        let maxChars = 30
        let displayText = block.text.count > maxChars
            ? String(block.text.prefix(maxChars)) + "…"
            : block.text

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: displayText, attributes: attrs)
        let textSize = attrStr.size()

        let pillPadding: CGFloat = 4
        let pillW = textSize.width + pillPadding * 2
        let pillH = textSize.height + pillPadding
        let pillX = rect.minX
        let pillY = rect.minY - pillH - 2

        // Clamp pill inside view bounds (for isFlipped=true, minY is the top)
        let clampedPillY = max(0, pillY)

        let pillRect = NSRect(x: pillX, y: clampedPillY, width: pillW, height: pillH)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: 3, yRadius: 3)

        context.saveGState()
        NSColor.black.withAlphaComponent(0.7).setFill()
        path.fill()
        context.restoreGState()

        attrStr.draw(at: NSPoint(x: pillX + pillPadding, y: clampedPillY + pillPadding / 2))
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newIndex = textBlocks.indices.first { blockRect(for: textBlocks[$0]).contains(point) }
        if newIndex != hoveredBlockIndex {
            hoveredBlockIndex = newIndex
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = textBlocks.indices.first(where: { blockRect(for: textBlocks[$0]).contains(point) }) else { return }

        onCopyBlock(textBlocks[index].text)
        flashBlock(at: index)
    }

    private func flashBlock(at index: Int) {
        flashTimer?.invalidate()
        flashingBlockIndex = index
        needsDisplay = true

        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.flashingBlockIndex = nil
            self?.needsDisplay = true
        }
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onDismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Button Actions

    @objc private func copyAllClicked() {
        let allText = textBlocks.map(\.text).joined(separator: "\n")
        onCopyAll()
        _ = allText // used by caller via onCopyAll closure
    }

    @objc private func dismissClicked() {
        onDismiss()
    }
}
