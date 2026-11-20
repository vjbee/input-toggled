// input-toggled: standalone resident daemon.
// Captures cmd+space via CGEventTap (swallowing it before the system sees it)
// and toggles Thai/English input source directly through the TIS API — silently.
// No Raycast, no TextInputSwitcher, no third-party dependency. Requires a
// one-time Accessibility grant (TCC) for the event tap.
import Cocoa
import Carbon

// MARK: - Toggle logic

// Preferred layouts, checked in order among the *enabled* input sources.
// If none match, any enabled keyboard source whose primary language is
// th / en is used, so other Thai or English layouts also work.
let thaiPreferred = ["com.apple.keylayout.Thai", "com.apple.keylayout.Thai-Pattachote"]
let enPreferred = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]

func property<T>(_ src: TISInputSource, _ key: CFString) -> T? {
    guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? T
}

func sourceID(_ src: TISInputSource) -> String {
    property(src, kTISPropertyInputSourceID) ?? "?"
}

/// Enabled, selectable keyboard input sources (re-read each call so changes
/// made in System Settings are picked up without restarting the daemon).
func enabledKeyboardSources() -> [TISInputSource] {
    let filter = [
        kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
        kTISPropertyInputSourceIsSelectCapable as String: true,
    ] as CFDictionary
    return TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
}

func pickSource(_ sources: [TISInputSource], preferred: [String], language: String) -> TISInputSource? {
    for id in preferred {
        if let src = sources.first(where: { sourceID($0) == id }) { return src }
    }
    return sources.first { src in
        let langs: [String] = property(src, kTISPropertyInputSourceLanguages) ?? []
        return langs.first == language
    }
}

func detectPair() -> (thai: TISInputSource, en: TISInputSource)? {
    let sources = enabledKeyboardSources()
    guard let thai = pickSource(sources, preferred: thaiPreferred, language: "th"),
          let en = pickSource(sources, preferred: enPreferred, language: "en") else { return nil }
    return (thai, en)
}

func currentID() -> String {
    guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "?" }
    return sourceID(src)
}

func toggleInputSource() {
    guard let pair = detectPair() else {
        print("input-toggled: need one Thai and one English keyboard layout enabled; found:",
              enabledKeyboardSources().map(sourceID))
        return
    }
    let target = currentID() == sourceID(pair.thai) ? pair.en : pair.thai
    TISSelectInputSource(target)
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
                DispatchQueue.main.async { toggleInputSource() }
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

if let pair = detectPair() {
    print("input-toggled: toggling", sourceID(pair.thai), "<->", sourceID(pair.en))
} else {
    print("input-toggled: WARNING no Thai/English layout pair enabled; found:",
          enabledKeyboardSources().map(sourceID))
}

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
