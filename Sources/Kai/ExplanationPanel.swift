import AppKit

final class ExplanationPanel: NSObject, NSTextFieldDelegate {
    private var panel: NSPanel!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var inputField: NSTextField!
    private var inputContainer: NSView!
    private var visualEffect: NSVisualEffectView!
    private var spinner: HelixSpinner!
    private var currentQuestion: String?
    /// Called when user submits a follow-up question
    var onFollowUp: ((String) -> Void)?

    // Reading cursor
    private var readingLine: Int = 0
    private static let cursorBg = NSColor(white: 1.0, alpha: 0.12)

    // Blackboard-style dark background with Xcode Dark syntax palette
    private static let bg        = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.10, alpha: 0.15)
    private static let fg        = NSColor(white: 0.90, alpha: 1.0)
    private static let comment   = NSColor(white: 0.48, alpha: 1.0)
    private static let dim       = NSColor(white: 0.62, alpha: 1.0)
    private static let cyan      = NSColor(red: 0.404, green: 0.718, blue: 0.812, alpha: 1.0)
    private static let green     = NSColor(red: 0.514, green: 0.753, blue: 0.404, alpha: 1.0)
    private static let orange    = NSColor(red: 0.835, green: 0.557, blue: 0.337, alpha: 1.0)
    private static let pink      = NSColor(red: 0.812, green: 0.400, blue: 0.600, alpha: 1.0)
    private static let purple    = NSColor(red: 0.631, green: 0.467, blue: 0.812, alpha: 1.0)
    private static let yellow    = NSColor(red: 0.843, green: 0.753, blue: 0.384, alpha: 1.0)
    private static let selection = NSColor.white.withAlphaComponent(0.25)
    private static let inputBg   = NSColor(white: 0.0, alpha: 0.18)

    private static let inputHeight: CGFloat = 36

    override init() {
        super.init()

        let width: CGFloat = 462
        let height: CGFloat = 242

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
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.animationBehavior = .utilityWindow
        panel.hasShadow = true
        panel.minSize = NSSize(width: 280, height: 160)

        // Blur behind the transparent window
        visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .underWindowBackground
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor

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
        textView.font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        textView.textColor = Self.fg
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
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
        separator.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.3).cgColor
        separator.autoresizingMask = [.width]
        inputContainer.addSubview(separator)

        inputField = NSTextField(frame: NSRect(x: 10, y: 6, width: width - 20, height: 24))
        inputField.isBordered = false
        inputField.focusRingType = .none
        inputField.font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        inputField.textColor = Self.fg
        inputField.backgroundColor = .clear
        inputField.drawsBackground = false
        inputField.placeholderAttributedString = NSAttributedString(
            string: "> ask a follow-up…",
            attributes: [.foregroundColor: Self.comment, .font: NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)]
        )
        inputField.delegate = self
        inputField.autoresizingMask = [.width]
        inputContainer.addSubview(inputField)
        inputContainer.autoresizingMask = [.width]

        // Layout: scroll view above input bar
        scrollView.frame = NSRect(x: 0, y: Self.inputHeight, width: width, height: height - Self.inputHeight)
        inputContainer.frame = NSRect(x: 0, y: 0, width: width, height: Self.inputHeight)

        visualEffect.addSubview(inputContainer)

        // Helix spinner — sits at top-left of text area, acts as Kai's mark.
        // Animates while thinking, freezes in place when response arrives.
        let spinnerW: CGFloat = 45
        let spinnerH: CGFloat = 27
        let spinnerPadX: CGFloat = 12
        let spinnerTopMargin: CGFloat = 14
        let spinnerBottomGap: CGFloat = 2
        spinner = HelixSpinner(frame: NSRect(
            x: spinnerPadX,
            y: scrollView.frame.maxY - spinnerH - spinnerTopMargin,
            width: spinnerW,
            height: spinnerH
        ))
        spinner.autoresizingMask = [.minYMargin]
        visualEffect.addSubview(spinner)

        // Push the text down so it starts below the spinner
        textView.textContainerInset = NSSize(
            width: 12,
            height: spinnerTopMargin + spinnerH + spinnerBottomGap
        )

        panel.contentView = visualEffect

        // Key handling — Escape closes, arrows move reading cursor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }

            // Let all keys pass through to the input field when it's focused
            let inputFocused = self.panel.firstResponder is NSTextView &&
                self.panel.firstResponder != self.textView &&
                self.inputField.currentEditor() != nil
            if inputFocused && event.keyCode != 53 {
                return event
            }

            if event.keyCode == 53 {
                self.close()
                return nil
            }

            // Cmd+C — copy selected text from the read-only text view
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
                if let selectedRange = self.textView.selectedRanges.first as? NSRange,
                   selectedRange.length > 0,
                   let text = self.textView.textStorage?.attributedSubstring(from: selectedRange).string {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                return nil
            }

            // Cmd+A — select all text
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
                self.textView.selectAll(nil)
                return nil
            }

            // Down arrow (keyCode 125) or Up arrow (keyCode 126)
            if event.keyCode == 125 {
                self.moveReadingCursor(by: 1)
                return nil
            }
            if event.keyCode == 126 {
                self.moveReadingCursor(by: -1)
                return nil
            }

            // Typed printable character with input unfocused — redirect to input.
            if !inputFocused,
               !event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.control),
               let chars = event.characters, !chars.isEmpty,
               chars.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) {
                self.panel.makeFirstResponder(self.inputField)
                self.inputField.currentEditor()?.insertText(chars)
                self.inputContainer.alphaValue = 1.0
                return nil
            }

            return event
        }
    }

    func show(text: String) {
        spinner.stop()
        let combined = NSMutableAttributedString()
        combined.append(questionPrefix())
        combined.append(styledText(text))
        textView.textStorage?.setAttributedString(combined)
        inputField.stringValue = ""
        inputContainer.alphaValue = 0.5
        readingLine = 0
        applyReadingCursor()
        resizeToFitContent()
        textView.scrollToBeginningOfDocument(nil)
        panel.orderFront(nil)
        // Unfocus the input so arrow keys drive the reading cursor.
        // A printable keypress will refocus the input via the event monitor.
        panel.makeFirstResponder(nil)
    }

    func showEmpty() {
        spinner.stop()
        currentQuestion = nil
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        inputField.stringValue = ""
        inputContainer.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(inputField)
    }

    func showThinking(question: String? = nil) {
        currentQuestion = question
        textView.textStorage?.setAttributedString(questionPrefix())
        inputField.stringValue = ""
        inputContainer.alphaValue = 0.5
        spinner.start()
        panel.orderFront(nil)
        panel.makeFirstResponder(inputField)
    }

    func update(text: String) {
        spinner.stop()
        let combined = NSMutableAttributedString()
        combined.append(questionPrefix())
        combined.append(styledText(text))
        textView.textStorage?.setAttributedString(combined)
        readingLine = 0
        applyReadingCursor()
        resizeToFitContent()
        // Unfocus input so arrows scroll paragraphs; typing refocuses it.
        panel.makeFirstResponder(nil)
    }

    private func questionPrefix() -> NSAttributedString {
        guard let q = currentQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !q.isEmpty else { return NSAttributedString() }
        let font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 8
        para.lineSpacing = 1
        return NSAttributedString(string: "> \(q)\n", attributes: [
            .font: font,
            .foregroundColor: Self.comment,
            .paragraphStyle: para
        ])
    }

    private func resizeToFitContent() {
        guard let lm = textView.layoutManager, let tc = textView.textContainer else { return }
        lm.ensureLayout(for: tc)
        let textHeight = ceil(lm.usedRect(for: tc).height)

        let insetV = textView.textContainerInset.height   // same top & bottom
        let desired = textHeight + insetV * 2 + Self.inputHeight + 4

        let screen = NSScreen.main?.visibleFrame ?? panel.frame
        let maxH: CGFloat = screen.height - 24
        let minH: CGFloat = 160
        let newH = min(max(desired, minH), maxH)

        var f = panel.frame
        let delta = newH - f.height
        guard abs(delta) > 0.5 else { return }
        // Grow/shrink while keeping the top edge anchored
        f.origin.y -= delta
        f.size.height = newH
        f.origin.y = max(f.origin.y, screen.minY + 8)
        panel.setFrame(f, display: true, animate: false)
    }

    // func appendToThread(question: String, answer: String) {
    //     — threading disabled: only the most recent Q&A is shown via show()
    // }

    func close() {
        spinner.stop()
        panel.orderOut(nil)
    }

    var isVisible: Bool { panel.isVisible }

    /// Re-show the panel without clearing any existing content or conversation state.
    func reopen() {
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(inputField)
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

    // MARK: - Reading cursor

    /// Returns ranges of non-empty logical lines (paragraphs), skipping blank lines.
    private func contentLineRanges() -> [NSRange] {
        guard let storage = textView.textStorage else { return [] }
        let string = storage.string as NSString
        var ranges: [NSRange] = []
        var start = questionPrefix().length
        if start > string.length { start = 0 }
        while start < string.length {
            let lineRange = string.lineRange(for: NSRange(location: start, length: 0))
            // Skip blank lines (only whitespace/newline)
            let content = string.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                ranges.append(lineRange)
            }
            start = NSMaxRange(lineRange)
        }
        return ranges
    }

    private func applyReadingCursor() {
        guard let lm = textView.layoutManager, textView.textContainer != nil,
              let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)

        let lines = contentLineRanges()
        guard readingLine >= 0, readingLine < lines.count else { return }
        let active = lines[readingLine]

        // Dim everything outside the active paragraph
        let dim = Self.comment
        if active.location > 0 {
            lm.addTemporaryAttribute(.foregroundColor, value: dim,
                forCharacterRange: NSRange(location: 0, length: active.location))
        }
        let activeEnd = NSMaxRange(active)
        if activeEnd < storage.length {
            lm.addTemporaryAttribute(.foregroundColor, value: dim,
                forCharacterRange: NSRange(location: activeEnd, length: storage.length - activeEnd))
        }
    }

    private func moveReadingCursor(by delta: Int) {
        let lines = contentLineRanges()
        guard !lines.isEmpty else { return }
        let newLine = max(0, min(lines.count - 1, readingLine + delta))
        guard newLine != readingLine else { return }
        readingLine = newLine
        applyReadingCursor()
        scrollReadingLineIntoView()
    }

    private func scrollReadingLineIntoView() {
        let lines = contentLineRanges()
        guard readingLine >= 0, readingLine < lines.count,
              let lm = textView.layoutManager, let tc = textView.textContainer else { return }
        let glyphRange = lm.glyphRange(forCharacterRange: lines[readingLine], actualCharacterRange: nil)
        let lineRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let scrollRect = lineRect.offsetBy(dx: textView.textContainerInset.width, dy: textView.textContainerInset.height)
        textView.scrollToVisible(scrollRect)
    }

    // MARK: - Styling

    private func styledText(_ text: String) -> NSAttributedString {
        let sf = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        let sfBold = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .bold)
        let mono = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .bold)
        let result = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        paragraphStyle.paragraphSpacing = 2

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: sf,
            .foregroundColor: Self.fg,
            .paragraphStyle: paragraphStyle
        ]

        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""

            if line.hasPrefix("```") {
                inCodeBlock.toggle()
                continue  // hide the ``` delimiters
            }

            if inCodeBlock {
                result.append(highlightCode(line + suffix, font: mono, boldFont: monoBold, style: paragraphStyle))
                continue
            }

            // Strip heading markers, render as bold
            if line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") {
                let stripped = line.replacingOccurrences(of: #"^#{1,3} "#, with: "", options: .regularExpression)
                let attrs = baseAttrs.merging([.font: sfBold]) { _, new in new }
                result.append(NSAttributedString(string: stripped + suffix, attributes: attrs))
                continue
            }

            // Strip **bold** markers, render as semibold inline
            if line.contains("**") {
                let parts = line.components(separatedBy: "**")
                for (j, part) in parts.enumerated() {
                    if j % 2 == 1 {
                        let attrs = baseAttrs.merging([.font: sfBold]) { _, new in new }
                        result.append(NSAttributedString(string: part, attributes: attrs))
                    } else {
                        result.append(NSAttributedString(string: part, attributes: baseAttrs))
                    }
                }
                result.append(NSAttributedString(string: suffix, attributes: baseAttrs))
                continue
            }

            // Strip `inline code` backticks, render in mono
            if line.contains("`") {
                let parts = line.components(separatedBy: "`")
                for (j, part) in parts.enumerated() {
                    if j % 2 == 1 {
                        let attrs = baseAttrs.merging([.font: mono, .foregroundColor: Self.green]) { _, new in new }
                        result.append(NSAttributedString(string: part, attributes: attrs))
                    } else {
                        result.append(NSAttributedString(string: part, attributes: baseAttrs))
                    }
                }
                result.append(NSAttributedString(string: suffix, attributes: baseAttrs))
                continue
            }

            // Bullets — keep the marker but dim it
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                let bulletAttrs = baseAttrs.merging([.foregroundColor: Self.dim]) { _, new in new }
                result.append(NSAttributedString(string: "· ", attributes: bulletAttrs))
                result.append(NSAttributedString(string: String(line.dropFirst(2)) + suffix, attributes: baseAttrs))
                continue
            }

            // Numbered lists
            if let range = line.range(of: #"^\d+[\.\)] "#, options: .regularExpression) {
                let num = String(line[range])
                let rest = String(line[range.upperBound...]) + suffix
                let numAttrs = baseAttrs.merging([.foregroundColor: Self.dim]) { _, new in new }
                result.append(NSAttributedString(string: num, attributes: numAttrs))
                result.append(NSAttributedString(string: rest, attributes: baseAttrs))
                continue
            }

            result.append(NSAttributedString(string: line + suffix, attributes: baseAttrs))
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

}
