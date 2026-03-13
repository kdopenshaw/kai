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
        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

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
        print("[Kai] Event tap created successfully")
    }

    fileprivate func handleFlags(_ flags: CGEventFlags) {
        let wanted: CGEventFlags = [.maskControl, .maskShift]
        let unwanted: CGEventFlags = [.maskCommand, .maskAlternate]

        let hasWanted = flags.contains(wanted)
        let hasUnwanted = !flags.intersection(unwanted).isEmpty

        print("[Kai] flags: \(flags.rawValue) hasWanted: \(hasWanted) hasUnwanted: \(hasUnwanted)")

        guard hasWanted && !hasUnwanted else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFireTime >= debounceInterval else { return }
        lastFireTime = now

        print("[Kai] Hotkey triggered!")
        handler()
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // Re-enable the tap if macOS disables it
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.handleFlags(event.flags)

    return Unmanaged.passRetained(event)
}
