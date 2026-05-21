import Cocoa
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private let maxBuffer = 64

    var isActive: Bool { eventTap != nil }

    func start() {
        guard AXIsProcessTrusted() else {
            NSLog("[HotKey] Accessibility fehlt")
            requestAccessibility()
            return
        }
        // macOS 10.15+: Input Monitoring ist eine eigene Berechtigung.
        // CGEventTap gibt auch ohne sie einen non-nil Port zurück – empfängt aber keine Events.
        // Deshalb explizit prüfen, bevor der Tap erstellt wird.
        guard CGPreflightListenEventAccess() else {
            NSLog("[HotKey] Input Monitoring fehlt – fordere an")
            CGRequestListenEventAccess()
            DispatchQueue.main.async { self.showAccessAlert(missing: .inputMonitoring) }
            return
        }
        NSLog("[HotKey] Accessibility + Input Monitoring OK – erstelle Event Tap")
        createTap()
        if eventTap == nil {
            NSLog("[HotKey] FEHLER: Tap-Erstellung fehlgeschlagen trotz Berechtigungen")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // Nach setActivationPolicy(.accessory) aufrufen.
    // macOS 26 deaktiviert den Tap beim Wechsel. Run-Loop-Source neu eintragen
    // und tapEnable senden, ohne den Port zu zerstören.
    func ensureEnabled() {
        guard let tap = eventTap else {
            NSLog("[HotKey] ensureEnabled: kein Tap – neu erstellen")
            guard AXIsProcessTrusted() else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.createTap()
            }
            return
        }
        // Run-Loop-Source neu registrieren (macOS kann sie beim Policy-Wechsel entfernen)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[HotKey] ensureEnabled: Tap reaktiviert")
    }

    private func createTap() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            NSLog("[HotKey] FEHLER: CGEvent.tapCreate ist fehlgeschlagen – prüfe Accessibility")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[HotKey] Event Tap aktiv")
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Tap wurde deaktiviert (z. B. nach Timeout) – sofort neu aktivieren
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("[HotKey] Tap deaktiviert (type=%d) – reaktiviere", type.rawValue)
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Modifier-Kombinationen ignorieren
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer = ""
            return Unmanaged.passRetained(event)
        }

        // Nicht-druckbare Tasten
        switch keyCode {
        case 51: // Backspace: letztes Zeichen aus Buffer entfernen
            if !buffer.isEmpty { buffer.removeLast() }
            return Unmanaged.passRetained(event)
        case 36, 48, 53, 123, 124, 125, 126: // Return, Tab, Escape, Pfeile
            buffer = ""
            return Unmanaged.passRetained(event)
        default:
            break
        }

        if let ch = unicodeChar(from: event) {
            buffer.append(ch)
            if buffer.count > maxBuffer {
                buffer = String(buffer.suffix(maxBuffer))
            }
            NSLog("[HotKey] Buffer: '%@'", buffer)

            if let match = SnippetManager.shared.match(buffer: buffer) {
                NSLog("[HotKey] Treffer: '%@' → '%@'", match.trigger, match.expansion)
                buffer = ""
                let trigger = match.trigger
                let expansion = match.expansion
                DispatchQueue.main.async {
                    self.replace(trigger: trigger, with: expansion)
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func replace(trigger: String, with expansion: String) {
        // Trigger-Zeichen löschen (inkl. des zuletzt getippten Zeichens)
        for _ in trigger {
            postKey(keyCode: 51, keyDown: true)
            postKey(keyCode: 51, keyDown: false)
        }

        // Expansion über Zwischenablage einfügen
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(expansion, forType: .string)

        // Kleines Delay damit die Backspaces ankommen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.postKey(keyCode: 9, keyDown: true, flags: .maskCommand)
            self.postKey(keyCode: 9, keyDown: false, flags: .maskCommand)

            // Zwischenablage wiederherstellen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pb.clearContents()
                if let prev = previous { pb.setString(prev, forType: .string) }
            }
        }
    }

    private func postKey(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { return }
        if !flags.isEmpty { event.flags = flags }
        event.post(tap: .cghidEventTap)
    }

    private func requestAccessibility() {
        // System-Prompt auslösen (öffnet Systemeinstellungen auf macOS 13 nicht mehr automatisch)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
        // Zusätzlich eigenen Dialog zeigen, da der System-Prompt oft unsichtbar bleibt
        DispatchQueue.main.async { self.showAccessAlert(missing: .accessibility) }
    }

    private enum MissingPermission { case accessibility, inputMonitoring }

    private func showAccessAlert(missing: MissingPermission) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        switch missing {
        case .accessibility:
            alert.messageText = "Jellyfish braucht Bedienungshilfen-Zugriff"
            alert.informativeText = """
                Damit Jellyfish Tastatureingaben erkennen kann, musst du die App in den Systemeinstellungen freigeben:

                Datenschutz & Sicherheit → Bedienungshilfen → Jellyfish ✓

                Starte Jellyfish danach neu.
                """
            alert.addButton(withTitle: "Bedienungshilfen öffnen")
            alert.addButton(withTitle: "Später")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        case .inputMonitoring:
            alert.messageText = "Jellyfish braucht Eingabeüberwachung"
            alert.informativeText = """
                Damit Jellyfish Tastatureingaben erkennen kann, musst du die App in den Systemeinstellungen freigeben:

                Datenschutz & Sicherheit → Eingabeüberwachung → Jellyfish ✓

                Starte Jellyfish danach neu.
                """
            alert.addButton(withTitle: "Eingabeüberwachung öffnen")
            alert.addButton(withTitle: "Später")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
            }
        }
        NSApp.setActivationPolicy(.accessory)
    }
}

// Übersetzt einen CGEvent-Tastendruck in ein Unicode-Zeichen.
// Nutzt TIS/UCKeyTranslate statt keyboardGetUnicodeString, das in Tap-Callbacks
// unzuverlässig sein kann.
private func unicodeChar(from event: CGEvent) -> Character? {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
        return nil
    }

    let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
    return layoutData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Character? in
        guard let base = ptr.baseAddress else { return nil }
        let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let modifiers = UInt32((flags.rawValue >> 16) & 0xFF)
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            modifiers,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        let str = String(utf16CodeUnits: Array(chars.prefix(length)), count: length)
        guard str.count == 1, let ch = str.first,
              !ch.isWhitespace, !ch.isNewline,
              ch.asciiValue.map({ $0 >= 32 }) ?? true else { return nil }
        return ch
    }
}
