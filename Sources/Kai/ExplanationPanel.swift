import AppKit

final class ExplanationPanel: NSObject {
    private var panel: NSPanel!
    private var textView: NSTextView!

    override init() {
        super.init()

        let width: CGFloat = 360
        let height: CGFloat = 180

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
        panel.animationBehavior = .utilityWindow

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        panel.contentView = scrollView

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
        textView.string = text
        panel.orderFront(nil)
    }

    func update(text: String) {
        textView.string = text
    }

    func close() {
        panel.orderOut(nil)
    }
}
