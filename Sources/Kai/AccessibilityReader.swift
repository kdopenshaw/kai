import AppKit
import ApplicationServices
import Foundation

final class AccessibilityReader {
    func getSelectedText() -> String? {
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "<unknown>"
        NSLog("[Kai] Frontmost app: \(frontApp)")

        if let text = getSelectedTextViaAX(), !text.isEmpty {
            NSLog("[Kai] AX API returned \(text.count) chars")
            return text
        }
        NSLog("[Kai] AX API returned nil/empty — falling back to clipboard")

        let result = getSelectedTextViaClipboard()
        NSLog("[Kai] Clipboard fallback returned \(result?.count ?? -1) chars")
        return result
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

        // Spin the runloop instead of blocking — our own CGEventTap callback
        // runs on this thread, and blocking would stop it from forwarding the
        // synthetic Cmd+C to the focused app.
        let deadline = Date(timeIntervalSinceNow: 0.2)
        while Date() < deadline && pasteboard.changeCount == oldChangeCount {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }

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
