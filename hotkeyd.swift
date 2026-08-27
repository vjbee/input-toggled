// input-toggled: standalone resident daemon.
// Captures cmd+space via CGEventTap (swallowing it before the system sees it)
// and toggles Thai/US input source directly through the TIS API — silently.
// No Raycast, no TextInputSwitcher, no third-party dependency. Requires a
// one-time Accessibility grant (TCC) for the event tap.
import Cocoa
import Carbon

// MARK: - Toggle logic

func findSource(_ id: String) -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return nil }
    return list.first
}

func currentID() -> String {
    guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return "?" }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}

let thaiID = "com.apple.keylayout.Thai"
let usID = "com.apple.keylayout.US"

func toggleInputSource() -> String {
    let target = currentID() == thaiID ? usID : thaiID
    if let src = findSource(target) {
        TISSelectInputSource(src)
    }
    return target == thaiID ? "ไทย" : "EN"
}

// MARK: - Event tap

var tapRef: CFMachPort?

let eventMask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.tapDisabledByTimeout.rawValue) |
    (1 << CGEventType.tapDisabledByUserInput.rawValue)

func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = tapRef { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    if keycode == 49 { // space
        let mods: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        if event.flags.intersection(mods) == .maskCommand {
            // swallow immediately; do the work off the tap's critical path
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
            if !isRepeat {
                DispatchQueue.main.async { _ = toggleInputSource() }
            }
            return nil
        }
    }
    return Unmanaged.passUnretained(event)
}

func startTap() -> Bool {
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                      place: .headInsertEventTap,
                                      options: .defaultTap,
                                      eventsOfInterest: eventMask,
                                      callback: tapCallback,
                                      userInfo: nil) else { return false }
    tapRef = tap
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    print("input-toggled: event tap active")
    return true
}

// MARK: - Main

setvbuf(stdout, nil, _IONBF, 0)

// Ask for Accessibility (shows the system prompt on first run)
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
_ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

if !startTap() {
    print("input-toggled: waiting for Accessibility permission...")
    Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { t in
        if startTap() { t.invalidate() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.run()
