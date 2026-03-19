import AppKit

final class OCROverlayView: NSView {
    private let textBlocks: [RecognizedTextBlock]
    private let imageSize: CGSize
    private let onCopyAll: () -> Void
    private let onDismiss: () -> Void

    private var copyAllButton: NSButton?
    private var dismissButton: NSButton?
    private var textView: NSTextView?
    private var scrollView: NSScrollView?

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
        self.onCopyAll = onCopyAll
        self.onDismiss = onDismiss
        super.init(frame: .zero)

        setupSingleTextView()
        setupControlButtons()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Block Rects

    private func blockRect(for block: RecognizedTextBlock) -> NSRect {
        let x = block.boundingBox.origin.x * imageSize.width
        let y = (1.0 - block.boundingBox.origin.y - block.boundingBox.height) * imageSize.height
        let w = block.boundingBox.width * imageSize.width
        let h = block.boundingBox.height * imageSize.height
        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Setup

    private func setupSingleTextView() {
        guard !textBlocks.isEmpty else { return }

        // Build a single attributed string with all blocks, using paragraph spacing
        // to approximate vertical positions from the image
        let fullAttr = NSMutableAttributedString()

        // Sort blocks top-to-bottom (they should already be sorted, but ensure it)
        let sorted = textBlocks.sorted { lhs, rhs in
            let lhsY = (1.0 - lhs.boundingBox.origin.y - lhs.boundingBox.height)
            let rhsY = (1.0 - rhs.boundingBox.origin.y - rhs.boundingBox.height)
            if abs(lhsY - rhsY) > 0.005 { return lhsY < rhsY }
            return lhs.boundingBox.origin.x < rhs.boundingBox.origin.x
        }

        // Calculate rects in pixel space
        let blockRects = sorted.map { blockRect(for: $0) }

        for (i, block) in sorted.enumerated() {
            let rect = blockRects[i]
            let fontSize = max(8, rect.height / 1.2)

            // Calculate spacing before this block
            var spacingBefore: CGFloat = 0
            if i > 0 {
                let prevRect = blockRects[i - 1]
                let gap = rect.minY - prevRect.maxY
                spacingBefore = max(0, gap)
            } else {
                spacingBefore = rect.minY
            }

            let para = NSMutableParagraphStyle()
            para.paragraphSpacingBefore = spacingBefore
            para.lineBreakMode = .byWordWrapping

            // Completely transparent text — only selection highlight visible
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: NSColor.clear,
                .paragraphStyle: para
            ]

            if i > 0 {
                fullAttr.append(NSAttributedString(string: "\n", attributes: attrs))
            }
            fullAttr.append(NSAttributedString(string: block.text, attributes: attrs))
        }

        // Use NSScrollView + NSTextView for proper text handling
        let sv = NSScrollView(frame: bounds)
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .noBorder
        sv.drawsBackground = false
        sv.autoresizingMask = [.width, .height]

        let tv = NSTextView(frame: bounds)
        tv.textStorage?.setAttributedString(fullAttr)
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.insertionPointColor = .clear
        tv.textContainerInset = NSSize.zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]

        // Selection: subtle semi-transparent highlight, white text
        tv.selectedTextAttributes = [
            .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.35),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]

        sv.documentView = tv
        addSubview(sv)
        scrollView = sv
        textView = tv
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

        scrollView?.frame = bounds

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

    // MARK: - Cursor

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
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
        onCopyAll()
    }

    @objc private func dismissClicked() {
        onDismiss()
    }
}
