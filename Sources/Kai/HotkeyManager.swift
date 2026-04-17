import CoreGraphics
import Foundation

final class HotkeyManager {
    private let handler: () -> Void
    private var eventTap: CFMachPort?
    private var lastFireTime: CFAbsoluteTime = 0
    private let debounceInterval: CFAbsoluteTime = 0.5

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        // Prevent self from being captured as a raw pointer issue — use Unmanaged
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: refcon
        ) else {
            print("Failed to create event tap. Is Accessibility enabled?")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[Kai] Event tap created successfully")
    }

    /// Returns true if the event should be consumed (not propagated to other apps).
    fileprivate func handleKey(_ keyCode: Int64) -> Bool {
        // F2 virtual key code
        guard keyCode == 120 else { return false }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastFireTime >= debounceInterval {
            lastFireTime = now
            NSLog("[Kai] Hotkey triggered!")
            handler()
        }
        // Always consume F2 so no other app sees it
        return true
    }

    fileprivate func reenableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[Kai] Event tap re-enabled")
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        manager.reenableTap()
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    if manager.handleKey(keyCode) {
        // Consume the event — no other app should see F2
        return nil
    }

    return Unmanaged.passRetained(event)
}
