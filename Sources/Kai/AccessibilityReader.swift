import AppKit
import ApplicationServices
import Foundation

final class AccessibilityReader {
    func getSelectedText() -> String? {
        // First try the Accessibility API (works in native apps)
        if let text = getSelectedTextViaAX(), !text.isEmpty {
            return text
        }

        // Fallback: simulate Cmd+C and read from clipboard (works in Chrome, etc.)
        return getSelectedTextViaClipboard()
    }

    private func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else {
            return nil
        }

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else {
            return nil
        }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
              let text = selectedText as? String else {
            return nil
        }

        return text
    }

    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        let oldChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Wait for the copy to complete
        usleep(100_000) // 100ms

        // Check if clipboard changed
        guard pasteboard.changeCount != oldChangeCount else {
            return nil
        }

        let text = pasteboard.string(forType: .string)

        // Restore old clipboard contents
        if let oldContents {
            pasteboard.clearContents()
            pasteboard.setString(oldContents, forType: .string)
        }

        return text
    }
}
