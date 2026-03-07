import AppKit

final class OCROverlayView: NSView {
    private let textBlocks: [RecognizedTextBlock]
    private let imageSize: CGSize
    private let onCopyBlock: (String) -> Void
    private let onCopyAll: () -> Void
    private let onDismiss: () -> Void

    private var copyAllButton: NSButton?
    private var dismissButton: NSButton?
    private var textViews: [NSTextView] = []
    private var pillButtons: [NSButton] = []

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

        setupTextViews()
        setupPillButtons()
        setupControlButtons()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

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

    // MARK: - Setup

    private func setupTextViews() {
        for block in textBlocks {
            let rect = blockRect(for: block)
            let fontSize = estimateFontSize(for: block, blockRect: rect)

            let textView = makeTextView(text: block.text, frame: rect, fontSize: fontSize)
            addSubview(textView)
            textViews.append(textView)
        }
    }

    private func makeTextView(text: String, frame: NSRect, fontSize: CGFloat) -> NSTextView {
        let textView = NSTextView(frame: frame)
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08)
        textView.textColor = NSColor.labelColor
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize.zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        // Allow natural selection cursor behavior (I-beam appears automatically)
        return textView
    }

    private func estimateFontSize(for block: RecognizedTextBlock, blockRect: NSRect) -> CGFloat {
        // Try to use average character height from characterRects
        if !block.characterRects.isEmpty {
            let avgNormHeight = block.characterRects.map(\.rect.height).reduce(0, +) / CGFloat(block.characterRects.count)
            let avgPixelHeight = avgNormHeight * imageSize.height
            // Font ascender is roughly 80% of total height
            let estimated = avgPixelHeight * 0.8
            if estimated > 6 { return estimated }
        }
        // Fallback: block height * 0.7
        return max(8, blockRect.height * 0.7)
    }

    private func setupPillButtons() {
        for (index, block) in textBlocks.enumerated() {
            let rect = blockRect(for: block)

            let maxChars = 30
            let displayText = block.text.count > maxChars
                ? String(block.text.prefix(maxChars)) + "…"
                : block.text

            let button = NSButton(title: displayText, target: self, action: #selector(pillButtonClicked(_:)))
            button.tag = index
            button.bezelStyle = .roundRect
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            button.layer?.cornerRadius = 4
            button.contentTintColor = NSColor.white
            button.font = NSFont.systemFont(ofSize: 10)

            // Size the button to fit its text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.white
            ]
            let textSize = (displayText as NSString).size(withAttributes: attrs)
            let pillPadding: CGFloat = 8
            let pillW = textSize.width + pillPadding * 2
            let pillH = textSize.height + 4
            let pillX = rect.minX
            // Place pill 2pt above the text block (above = smaller Y in flipped coords)
            let pillY = rect.minY - pillH - 2
            let clampedPillY = max(0, pillY)

            button.frame = NSRect(x: pillX, y: clampedPillY, width: pillW, height: pillH)
            addSubview(button)
            pillButtons.append(button)
        }
    }

    private func setupControlButtons() {
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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw subtle highlight behind each text block
        for block in textBlocks {
            let rect = blockRect(for: block)
            ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.05).cgColor)
            ctx.fill(rect)

            // Draw a subtle border so users can see text regions
            ctx.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect)
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

    @objc private func pillButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < textBlocks.count else { return }
        onCopyBlock(textBlocks[index].text)
    }

    @objc private func copyAllClicked() {
        onCopyAll()
    }

    @objc private func dismissClicked() {
        onDismiss()
    }
}
