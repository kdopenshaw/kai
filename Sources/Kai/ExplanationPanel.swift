import AppKit

final class ExplanationPanel: NSObject, NSTextFieldDelegate {
    private var panel: NSPanel!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var inputField: NSTextField!
    private var inputContainer: NSView!
    private var visualEffect: NSVisualEffectView!
    /// Called when user submits a follow-up question
    var onFollowUp: ((String) -> Void)?

    // Xcode Dark palette
    private static let bg        = NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 0.85)
    private static let fg        = NSColor(red: 0.871, green: 0.871, blue: 0.871, alpha: 1.0)
    private static let comment   = NSColor(red: 0.424, green: 0.475, blue: 0.529, alpha: 1.0)
    private static let cyan      = NSColor(red: 0.404, green: 0.718, blue: 0.812, alpha: 1.0)
    private static let green     = NSColor(red: 0.514, green: 0.753, blue: 0.404, alpha: 1.0)
    private static let orange    = NSColor(red: 0.835, green: 0.557, blue: 0.337, alpha: 1.0)
    private static let pink      = NSColor(red: 0.812, green: 0.400, blue: 0.600, alpha: 1.0)
    private static let purple    = NSColor(red: 0.631, green: 0.467, blue: 0.812, alpha: 1.0)
    private static let yellow    = NSColor(red: 0.843, green: 0.753, blue: 0.384, alpha: 1.0)
    private static let selection = NSColor(red: 0.200, green: 0.337, blue: 0.537, alpha: 1.0)
    private static let inputBg   = NSColor(red: 0.160, green: 0.160, blue: 0.160, alpha: 1.0)

    private static let inputHeight: CGFloat = 36

    override init() {
        super.init()

        let width: CGFloat = 420
        let height: CGFloat = 220

        // Position near mouse, clamped to screen
        let mouse = NSEvent.mouseLocation
        var frame = NSRect(x: mouse.x + 12, y: mouse.y - height - 12, width: width, height: height)

        if let screen = NSScreen.main?.visibleFrame {
            frame.origin.x = min(frame.origin.x, screen.maxX - width - 8)
            frame.origin.x = max(frame.origin.x, screen.minX + 8)
            frame.origin.y = max(frame.origin.y, screen.minY + 8)
            frame.origin.y = min(frame.origin.y, screen.maxY - height - 8)
        }

        panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.title = "Kai"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.animationBehavior = .utilityWindow
        panel.hasShadow = true

        // Blur behind the transparent window
        visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]

        // Tinted overlay for Xcode Dark color
        let tint = NSView(frame: visualEffect.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = Self.bg.cgColor
        tint.autoresizingMask = [.width, .height]
        visualEffect.addSubview(tint)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false

        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        textView.textColor = Self.fg
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.selectedTextAttributes = [
            .backgroundColor: Self.selection,
            .foregroundColor: Self.fg
        ]

        scrollView.documentView = textView
        visualEffect.addSubview(scrollView)

        // Input bar (always visible at bottom, dimmed until focused)
        inputContainer = NSView(frame: NSRect(x: 0, y: 0, width: width, height: Self.inputHeight))
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = Self.inputBg.cgColor
        inputContainer.alphaValue = 0.5

        // Separator line
        let separator = NSView(frame: NSRect(x: 0, y: Self.inputHeight - 1, width: width, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        separator.autoresizingMask = [.width]
        inputContainer.addSubview(separator)

        inputField = NSTextField(frame: NSRect(x: 10, y: 6, width: width - 20, height: 24))
        inputField.isBordered = false
        inputField.focusRingType = .none
        inputField.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        inputField.textColor = Self.fg
        inputField.backgroundColor = .clear
        inputField.drawsBackground = false
        inputField.placeholderAttributedString = NSAttributedString(
            string: "Ask a follow-up…",
            attributes: [.foregroundColor: Self.comment, .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)]
        )
        inputField.delegate = self
        inputField.autoresizingMask = [.width]
        inputContainer.addSubview(inputField)
        inputContainer.autoresizingMask = [.width]

        // Layout: scroll view above input bar
        scrollView.frame = NSRect(x: 0, y: Self.inputHeight, width: width, height: height - Self.inputHeight)
        inputContainer.frame = NSRect(x: 0, y: 0, width: width, height: Self.inputHeight)

        visualEffect.addSubview(inputContainer)
        panel.contentView = visualEffect

        // Key handling — Escape closes panel
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }

            if event.keyCode == 53 {
                self.close()
                return nil
            }

            return event
        }
    }

    func show(text: String) {
        textView.textStorage?.setAttributedString(styledText(text))
        inputField.stringValue = ""
        inputContainer.alphaValue = 0.5
        panel.orderFront(nil)
        // Focus the input field immediately so user can just start typing
        panel.makeFirstResponder(inputField)
    }

    func update(text: String) {
        textView.textStorage?.setAttributedString(styledText(text))
    }

    func appendToThread(question: String, answer: String) {
        let mono = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 6

        let current = NSMutableAttributedString(attributedString: textView.attributedString())

        // Add separator + question
        let separator = NSAttributedString(string: "\n\n", attributes: [.font: mono])
        let qLabel = NSAttributedString(string: "▶ ", attributes: [
            .foregroundColor: Self.cyan, .font: mono, .paragraphStyle: paragraphStyle
        ])
        let qText = NSAttributedString(string: question + "\n\n", attributes: [
            .foregroundColor: Self.fg, .font: monoBold, .paragraphStyle: paragraphStyle
        ])

        current.append(separator)
        current.append(qLabel)
        current.append(qText)

        // Add answer
        current.append(styledText(answer))

        textView.textStorage?.setAttributedString(current)
        // Scroll to bottom
        textView.scrollToEndOfDocument(nil)
    }

    func close() {
        panel.orderOut(nil)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidBeginEditing(_ obj: Notification) {
        inputContainer.alphaValue = 1.0
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if inputField.stringValue.isEmpty {
            inputContainer.alphaValue = 0.5
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter pressed — send follow-up
            let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            inputField.stringValue = ""
            inputContainer.alphaValue = 0.5
            onFollowUp?(text)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape in text field — unfocus
            inputField.stringValue = ""
            inputContainer.alphaValue = 0.5
            panel.makeFirstResponder(nil)
            return true
        }
        return false
    }

    // MARK: - Styling

    private func styledText(_ text: String) -> NSAttributedString {
        let mono = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .bold)
        let result = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 6

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: mono,
            .foregroundColor: Self.fg,
            .paragraphStyle: paragraphStyle
        ]

        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""
            let fullLine = line + suffix

            if line.hasPrefix("```") {
                inCodeBlock.toggle()
                let attrs = baseAttrs.merging([.foregroundColor: Self.comment]) { _, new in new }
                result.append(NSAttributedString(string: fullLine, attributes: attrs))
                continue
            }

            if inCodeBlock {
                result.append(highlightCode(fullLine, font: mono, boldFont: monoBold, style: paragraphStyle))
                continue
            }

            if line.contains("`") {
                result.append(highlightInlineCode(fullLine, baseAttrs: baseAttrs, font: mono))
                continue
            }

            if line.contains("**") {
                result.append(highlightBold(fullLine, baseAttrs: baseAttrs, boldFont: monoBold))
                continue
            }

            if line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") {
                let attrs = baseAttrs.merging([
                    .foregroundColor: Self.pink,
                    .font: monoBold
                ]) { _, new in new }
                result.append(NSAttributedString(string: fullLine, attributes: attrs))
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                let bullet = String(line.prefix(2))
                let rest = String(line.dropFirst(2)) + suffix
                let bulletAttrs = baseAttrs.merging([.foregroundColor: Self.cyan]) { _, new in new }
                result.append(NSAttributedString(string: bullet, attributes: bulletAttrs))
                result.append(NSAttributedString(string: rest, attributes: baseAttrs))
                continue
            }

            if let range = line.range(of: #"^\d+[\.\)] "#, options: .regularExpression) {
                let num = String(line[range])
                let rest = String(line[range.upperBound...]) + suffix
                let numAttrs = baseAttrs.merging([.foregroundColor: Self.cyan]) { _, new in new }
                result.append(NSAttributedString(string: num, attributes: numAttrs))
                result.append(NSAttributedString(string: rest, attributes: baseAttrs))
                continue
            }

            result.append(NSAttributedString(string: fullLine, attributes: baseAttrs))
        }

        return result
    }

    private func highlightCode(_ line: String, font: NSFont, boldFont: NSFont, style: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Self.fg,
            .paragraphStyle: style
        ]

        let keywords = ["func", "let", "var", "if", "else", "guard", "return", "import",
                        "class", "struct", "enum", "protocol", "for", "while", "switch",
                        "case", "break", "continue", "def", "self", "true", "false", "nil",
                        "async", "await", "try", "catch", "throw", "const", "function",
                        "public", "private", "static", "final", "override", "init"]
        let types = ["String", "Int", "Bool", "Double", "Float", "Array", "Dictionary",
                     "Optional", "Result", "Error", "URL", "Data", "void", "int", "str"]

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            let attrs = baseAttrs.merging([.foregroundColor: Self.comment]) { _, new in new }
            result.append(NSAttributedString(string: line, attributes: attrs))
            return result
        }

        var remaining = line[line.startIndex...]
        while !remaining.isEmpty {
            if remaining.first == "\"" || remaining.first == "'" {
                let quote = remaining.first!
                var end = remaining.index(after: remaining.startIndex)
                while end < remaining.endIndex && remaining[end] != quote {
                    if remaining[end] == "\\" && remaining.index(after: end) < remaining.endIndex {
                        end = remaining.index(after: end)
                    }
                    end = remaining.index(after: end)
                }
                if end < remaining.endIndex {
                    end = remaining.index(after: end)
                }
                let token = String(remaining[remaining.startIndex..<end])
                let attrs = baseAttrs.merging([.foregroundColor: Self.yellow]) { _, new in new }
                result.append(NSAttributedString(string: token, attributes: attrs))
                remaining = remaining[end...]
                continue
            }

            if remaining.first?.isNumber == true {
                var end = remaining.startIndex
                while end < remaining.endIndex && (remaining[end].isNumber || remaining[end] == ".") {
                    end = remaining.index(after: end)
                }
                let token = String(remaining[remaining.startIndex..<end])
                let attrs = baseAttrs.merging([.foregroundColor: Self.purple]) { _, new in new }
                result.append(NSAttributedString(string: token, attributes: attrs))
                remaining = remaining[end...]
                continue
            }

            if remaining.first?.isLetter == true || remaining.first == "_" {
                var end = remaining.startIndex
                while end < remaining.endIndex && (remaining[end].isLetter || remaining[end].isNumber || remaining[end] == "_") {
                    end = remaining.index(after: end)
                }
                let token = String(remaining[remaining.startIndex..<end])
                let color: NSColor
                if keywords.contains(token) {
                    color = Self.pink
                } else if types.contains(token) {
                    color = Self.cyan
                } else if remaining.startIndex > line.startIndex && line[line.index(before: remaining.startIndex)] == "." {
                    color = Self.green
                } else {
                    color = Self.fg
                }
                let attrs = baseAttrs.merging([.foregroundColor: color]) { _, new in new }
                result.append(NSAttributedString(string: token, attributes: attrs))
                remaining = remaining[end...]
                continue
            }

            let ch = String(remaining.first!)
            let attrs = baseAttrs.merging([.foregroundColor: Self.fg]) { _, new in new }
            result.append(NSAttributedString(string: ch, attributes: attrs))
            remaining = remaining[remaining.index(after: remaining.startIndex)...]
        }

        return result
    }

    private func highlightInlineCode(_ line: String, baseAttrs: [NSAttributedString.Key: Any], font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let parts = line.components(separatedBy: "`")
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                let attrs = baseAttrs.merging([.foregroundColor: Self.green]) { _, new in new }
                result.append(NSAttributedString(string: part, attributes: attrs))
            } else {
                result.append(NSAttributedString(string: part, attributes: baseAttrs))
            }
        }
        return result
    }

    private func highlightBold(_ line: String, baseAttrs: [NSAttributedString.Key: Any], boldFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let parts = line.components(separatedBy: "**")
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                let attrs = baseAttrs.merging([
                    .foregroundColor: Self.orange,
                    .font: boldFont
                ]) { _, new in new }
                result.append(NSAttributedString(string: part, attributes: attrs))
            } else {
                result.append(NSAttributedString(string: part, attributes: baseAttrs))
            }
        }
        return result
    }
}
