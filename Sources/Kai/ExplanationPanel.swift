import AppKit

final class ExplanationPanel: NSObject {
    private var panel: NSPanel!
    private var textView: NSTextView!

    // Dracula palette
    private static let bg        = NSColor(red: 0.157, green: 0.165, blue: 0.212, alpha: 0.92)
    private static let fg        = NSColor(red: 0.973, green: 0.973, blue: 0.949, alpha: 1.0)
    private static let comment   = NSColor(red: 0.384, green: 0.447, blue: 0.643, alpha: 1.0)
    private static let cyan      = NSColor(red: 0.545, green: 0.914, blue: 0.992, alpha: 1.0)
    private static let green     = NSColor(red: 0.314, green: 0.980, blue: 0.482, alpha: 1.0)
    private static let orange    = NSColor(red: 1.000, green: 0.722, blue: 0.424, alpha: 1.0)
    private static let pink      = NSColor(red: 1.000, green: 0.475, blue: 0.776, alpha: 1.0)
    private static let purple    = NSColor(red: 0.741, green: 0.576, blue: 0.976, alpha: 1.0)
    private static let yellow    = NSColor(red: 0.945, green: 0.980, blue: 0.549, alpha: 1.0)
    private static let selection = NSColor(red: 0.263, green: 0.278, blue: 0.353, alpha: 1.0)

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
            styleMask: [.nonactivatingPanel, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = Self.bg
        panel.alphaValue = 1.0
        panel.animationBehavior = .utilityWindow
        panel.hasShadow = true

        // Visual effect for subtle blur behind transparency
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 14, height: 14)
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
        panel.contentView = visualEffect

        // Rounded corners
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true

        // Dismiss on Escape
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    func show(text: String) {
        textView.textStorage?.setAttributedString(styledText(text))
        panel.orderFront(nil)
    }

    func update(text: String) {
        textView.textStorage?.setAttributedString(styledText(text))
    }

    func close() {
        panel.orderOut(nil)
    }

    /// Apply Dracula syntax highlighting to the response
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

            // Code block fences
            if line.hasPrefix("```") {
                inCodeBlock.toggle()
                let attrs = baseAttrs.merging([.foregroundColor: Self.comment]) { _, new in new }
                result.append(NSAttributedString(string: fullLine, attributes: attrs))
                continue
            }

            if inCodeBlock {
                // Inside code block — highlight syntax
                result.append(highlightCode(fullLine, font: mono, boldFont: monoBold, style: paragraphStyle))
                continue
            }

            // Inline code: `...`
            if line.contains("`") {
                result.append(highlightInlineCode(fullLine, baseAttrs: baseAttrs, font: mono))
                continue
            }

            // Bold text: **...**
            if line.contains("**") {
                result.append(highlightBold(fullLine, baseAttrs: baseAttrs, boldFont: monoBold))
                continue
            }

            // Headings / bullet points
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

            // Numbered lists
            if let range = line.range(of: #"^\d+[\.\)] "#, options: .regularExpression) {
                let num = String(line[range])
                let rest = String(line[range.upperBound...]) + suffix
                let numAttrs = baseAttrs.merging([.foregroundColor: Self.cyan]) { _, new in new }
                result.append(NSAttributedString(string: num, attributes: numAttrs))
                result.append(NSAttributedString(string: rest, attributes: baseAttrs))
                continue
            }

            // Default
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

        // Simple keyword-based highlighting
        let keywords = ["func", "let", "var", "if", "else", "guard", "return", "import",
                        "class", "struct", "enum", "protocol", "for", "while", "switch",
                        "case", "break", "continue", "def", "self", "true", "false", "nil",
                        "async", "await", "try", "catch", "throw", "const", "function",
                        "public", "private", "static", "final", "override", "init"]
        let types = ["String", "Int", "Bool", "Double", "Float", "Array", "Dictionary",
                     "Optional", "Result", "Error", "URL", "Data", "void", "int", "str"]

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Comments
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            let attrs = baseAttrs.merging([.foregroundColor: Self.comment]) { _, new in new }
            result.append(NSAttributedString(string: line, attributes: attrs))
            return result
        }

        // Tokenize and color
        var remaining = line[line.startIndex...]
        while !remaining.isEmpty {
            // String literals
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

            // Numbers
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

            // Words (identifiers/keywords)
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

            // Operators and punctuation
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
                // Inside backticks
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
