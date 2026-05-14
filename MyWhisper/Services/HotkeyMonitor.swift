import Cocoa
import CoreGraphics
import OSLog

private let log = Logger(subsystem: "com.mywhisper.app", category: "HotkeyMonitor")

enum HotkeyMonitorError: LocalizedError {
    case eventTapDenied

    var errorDescription: String? {
        switch self {
        case .eventTapDenied:
            return "Could not install keyboard monitor. Grant Accessibility permission to MyWhisper."
        }
    }
}

final class HotkeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false

    // Right Option key on Apple keyboards.
    private static let rightOptionKeyCode: Int64 = 61
    // NX_DEVICERALTKEYMASK from IOLLEvent.h — distinguishes right Option from left.
    private static let rightOptionFlagMask: UInt64 = 0x40

    func start() throws {
        if tap != nil { return }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let opaque = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            switch type {
            case .tapDisabledByTimeout:
                log.notice("event tap disabled by timeout — re-enabling")
                monitor.reEnable()
            case .tapDisabledByUserInput:
                log.notice("event tap disabled by user input — re-enabling")
                monitor.reEnable()
            case .flagsChanged:
                monitor.handle(event: event)
            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: opaque
        ) else {
            throw HotkeyMonitorError.eventTapDenied
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isHeld = false
    }

    private func reEnable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handle(event: CGEvent) {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keycode == Self.rightOptionKeyCode else { return }

        let pressed = (event.flags.rawValue & Self.rightOptionFlagMask) != 0
        log.debug("right-option event: pressed=\(pressed, privacy: .public), wasHeld=\(self.isHeld, privacy: .public)")
        if pressed && !isHeld {
            isHeld = true
            log.info("hotkey: press → onPress()")
            onPress()
        } else if !pressed && isHeld {
            isHeld = false
            log.info("hotkey: release → onRelease()")
            onRelease()
        }
    }
}
