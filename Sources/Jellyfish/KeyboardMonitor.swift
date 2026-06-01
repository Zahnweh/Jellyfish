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
            NSLog("[HotKey] Bedienungshilfen nicht erteilt")
            DispatchQueue.main.async { self.showPermissionsAlert() }
            return
        }
        createTap()
        if eventTap == nil {
            NSLog("[HotKey] Tap-Erstellung fehlgeschlagen")
        } else {
            NSLog("[HotKey] Event Tap aktiv")
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

        // Kein Matching während das Jellyfish-Panel offen ist.
        if NSApp.keyWindow != nil {
            buffer = ""
            // Picker geöffnet: Event direkt ans floating NSPanel senden.
            // NSEvent(cgEvent:) hat im Tap kein gültiges characters-Feld
            // (CGEventKeyboardGetUnicodeString ist im Tap unzuverlässig).
            // Deshalb: für druckbare Zeichen ein vollständiges NSEvent via
            // NSEvent.keyEvent(...) aufbauen; für Sondertasten CGEvent direkt.
            if let pickerPanel = SearchablePopupButton.activePickerPanel {
                let keyCode   = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let flags     = event.flags
                let modifiers = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
                let winNum    = pickerPanel.windowNumber
                let ts        = ProcessInfo.processInfo.systemUptime

                if let ch = unicodeChar(from: event) {
                    // Druckbares Zeichen: NSEvent mit korrektem characters-Feld
                    let s = String(ch)
                    if let nsEvent = NSEvent.keyEvent(
                        with: .keyDown, location: .zero,
                        modifierFlags: modifiers, timestamp: ts,
                        windowNumber: winNum, context: nil,
                        characters: s, charactersIgnoringModifiers: s,
                        isARepeat: false, keyCode: keyCode) {
                        DispatchQueue.main.async { pickerPanel.sendEvent(nsEvent) }
                    }
                } else {
                    // Sondertaste (Delete, Enter, Escape, Pfeile): CGEvent direkt
                    let retained = Unmanaged.passRetained(event)
                    DispatchQueue.main.async {
                        if let nsEvent = NSEvent(cgEvent: retained.takeRetainedValue()) {
                            pickerPanel.sendEvent(nsEvent)
                        }
                    }
                }
                return nil
            }
            return Unmanaged.passRetained(event)
        }

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
            if let match = SnippetManager.shared.match(buffer: buffer) {
                buffer = ""
                let trigger = match.trigger
                let expansion = match.expansion
                let rtf = match.rtf
                DispatchQueue.main.async {
                    // Zwischenablage jetzt lesen, bevor paste() sie überschreibt
                    let clipboardText = NSPasteboard.general.string(forType: .string) ?? ""

                    if let rtfData = rtf {
                        guard let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) else {
                            self.replace(trigger: trigger, with: expansion); return
                        }
                        let mutable = NSMutableAttributedString(attributedString: attrStr)
                        self.resolveStaticPlaceholders(in: mutable, clipboardText: clipboardText)

                        if DropdownPlaceholder.hasPlaceholders(in: mutable.string)
                            || OptionalPlaceholder.hasPlaceholders(in: mutable.string) {
                            let resolvedPlain = expansion.replacingOccurrences(of: "{ZWISCHENABLAGE}", with: clipboardText)
                            self.deleteTrigger(trigger)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                SnippetPreviewWindowController.shared.show(
                                    expansion: resolvedPlain, rtfAttrStr: mutable
                                ) { [weak self] final, resolvedAttrStr in
                                    if let resolvedAttrStr {
                                        self?.paste(attrStr: resolvedAttrStr, plainFallback: final)
                                    } else {
                                        self?.paste(final)
                                    }
                                }
                            }
                        } else {
                            let plain = mutable.string
                            self.deleteTrigger(trigger)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.paste(attrStr: mutable, plainFallback: plain)
                            }
                        }
                        return
                    }

                    // Plain text
                    let resolved = expansion.replacingOccurrences(of: "{ZWISCHENABLAGE}", with: clipboardText)

                    if DropdownPlaceholder.hasPlaceholders(in: resolved) || OptionalPlaceholder.hasPlaceholders(in: resolved) {
                        self.deleteTrigger(trigger)
                        // Delay so the backspace events reach the target app before the panel takes key focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            SnippetPreviewWindowController.shared.show(expansion: resolved) { [weak self] final, _ in
                                    self?.paste(final)
                                }
                        }
                    } else {
                        self.replace(trigger: trigger, with: resolved)
                    }
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func replace(trigger: String, with expansion: String) {
        deleteTrigger(trigger)
        paste(expansion)
    }

    private func deleteTrigger(_ trigger: String) {
        for _ in trigger {
            postKey(keyCode: 51, keyDown: true)
            postKey(keyCode: 51, keyDown: false)
        }
    }

    private func linkURL(from attrs: [NSAttributedString.Key: Any]) -> URL? {
        if let u = attrs[.link] as? URL    { return u }
        if let u = attrs[.link] as? NSURL  { return u as URL }
        if let s = attrs[.link] as? String { return URL(string: s) }
        return nil
    }

    private func simpleHTML(from attrStr: NSAttributedString) -> Data? {
        var fragment = ""
        attrStr.enumerateAttributes(in: NSRange(location: 0, length: attrStr.length), options: []) { attrs, range, _ in
            var text = (attrStr.string as NSString).substring(with: range)
            text = text.replacingOccurrences(of: "&", with: "&amp;")
                       .replacingOccurrences(of: "<", with: "&lt;")
                       .replacingOccurrences(of: ">", with: "&gt;")
                       .replacingOccurrences(of: "\n", with: "<br>")
            if let url = linkURL(from: attrs) {
                fragment += "<a href=\"\(url.absoluteString)\">\(text)</a>"
                return
            }
            var open = ""; var close = ""
            if let font = attrs[.font] as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                if traits.contains(.boldFontMask)   { open += "<strong>"; close = "</strong>" + close }
                if traits.contains(.italicFontMask) { open += "<em>";     close = "</em>"     + close }
            }
            if attrs[.underlineStyle] != nil { open += "<u>"; close = "</u>" + close }
            fragment += open + text + close
        }
        // Wenn der Inhalt NUR ein Link ist (kein umgebender Text), in <p> einwickeln
        // damit TinyMCE es als Rich-Content behandelt und nicht als nackten URL-Paste ignoriert
        let isOnlyLink = fragment.hasPrefix("<a ") && fragment.hasSuffix("</a>") && !fragment.dropFirst(3).contains("<a ")
        let body = isOnlyLink ? "<p>\(fragment)</p>" : fragment
        return "<meta charset=\"UTF-8\">\(body)".data(using: .utf8)
    }

    private func paste(attrStr: NSMutableAttributedString, plainFallback: String) {
        let range = NSRange(location: 0, length: attrStr.length)
        let rtfData  = attrStr.rtf(from: range, documentAttributes: [:])
        let htmlData = simpleHTML(from: attrStr)
        let pb = NSPasteboard.general
        let htmlUTI  = NSPasteboard.PasteboardType("public.html")
        let htmlMIME = NSPasteboard.PasteboardType("text/html")
        let prevString = pb.string(forType: .string)
        let prevRTF    = pb.data(forType: .rtf)
        let prevHTML   = pb.data(forType: htmlUTI)

        pb.clearContents()
        if let rtf  = rtfData  { pb.setData(rtf,  forType: .rtf) }
        if let html = htmlData {
            pb.setData(html, forType: htmlUTI)
            pb.setData(html, forType: htmlMIME)
        }
        pb.setString(plainFallback, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.postKey(keyCode: 9, keyDown: true, flags: .maskCommand)
            self.postKey(keyCode: 9, keyDown: false, flags: .maskCommand)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pb.clearContents()
                if let prev = prevRTF    { pb.setData(prev, forType: .rtf) }
                if let prev = prevHTML   { pb.setData(prev, forType: htmlUTI) }
                if let prev = prevString { pb.setString(prev, forType: .string) }
            }
        }
    }

    private func paste(rtf: Data, plainFallback: String) {
        let pb = NSPasteboard.general
        let previousString = pb.string(forType: .string)
        let previousRTF = pb.data(forType: .rtf)
        let htmlType = NSPasteboard.PasteboardType("public.html")
        let previousHTML = pb.data(forType: htmlType)

        pb.clearContents()
        pb.setData(rtf, forType: .rtf)
        pb.setString(plainFallback, forType: .string)

        // HTML für Browser und Web-Editoren (z.B. WordPress)
        if let attrStr = NSAttributedString(rtf: rtf, documentAttributes: nil),
           let htmlData = simpleHTML(from: attrStr) {
            pb.setData(htmlData, forType: htmlType)
            pb.setData(htmlData, forType: NSPasteboard.PasteboardType("text/html"))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.postKey(keyCode: 9, keyDown: true, flags: .maskCommand)
            self.postKey(keyCode: 9, keyDown: false, flags: .maskCommand)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pb.clearContents()
                if let prev = previousRTF { pb.setData(prev, forType: .rtf) }
                if let prev = previousHTML { pb.setData(prev, forType: htmlType) }
                if let prev = previousString { pb.setString(prev, forType: .string) }
            }
        }
    }

    private func paste(_ text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.postKey(keyCode: 9, keyDown: true, flags: .maskCommand)
            self.postKey(keyCode: 9, keyDown: false, flags: .maskCommand)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pb.clearContents()
                if let prev = previous { pb.setString(prev, forType: .string) }
            }
        }
    }

    // MARK: - RTF static placeholder resolution

    private func replaceAll(_ placeholder: String, with value: String, in attrStr: NSMutableAttributedString) {
        while true {
            let found = (attrStr.string as NSString).range(of: placeholder)
            guard found.location != NSNotFound else { break }
            attrStr.replaceCharacters(in: found, with: value)
        }
    }

    private func resolveStaticPlaceholders(in attrStr: NSMutableAttributedString, clipboardText: String) {
        replaceAll("{ZWISCHENABLAGE}", with: clipboardText, in: attrStr)
        let now = Date()
        for ph in DatePlaceholder.allCases {
            replaceAll(ph.rawValue, with: ph.resolve(at: now), in: attrStr)
        }
        guard attrStr.string.contains("{RECHNUNG|"),
              let regex = try? NSRegularExpression(pattern: #"\{RECHNUNG\|([^}]+)\}"#) else { return }
        while true {
            let str = attrStr.string
            guard let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) else { break }
            guard let innerRange = Range(match.range(at: 1), in: str) else { break }
            let parts = str[innerRange].split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let amount = Int(parts[0]),
                  let unit = DateArithmeticUnit(rawValue: parts[1]),
                  let ph = DatePlaceholder.allCases.first(where: { $0.displayName == parts[2] }),
                  let newDate = Calendar.current.date(byAdding: unit.calendarComponent, value: amount, to: now)
            else { attrStr.deleteCharacters(in: match.range); continue }
            attrStr.replaceCharacters(in: match.range, with: ph.resolve(at: newDate))
        }
    }

    private func postKey(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { return }
        if !flags.isEmpty { event.flags = flags }
        event.post(tap: .cghidEventTap)
    }

    private func showPermissionsAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Jellyfish braucht Bedienungshilfen-Zugriff"
        alert.informativeText = """
            Damit Jellyfish Textkürzel erkennen kann, musst du die App in den Systemeinstellungen freigeben:

            Datenschutz & Sicherheit → Bedienungshilfen → Jellyfish ✓

            Jellyfish startet danach automatisch neu.
            """
        alert.addButton(withTitle: "Systemeinstellungen öffnen")
        alert.addButton(withTitle: "Später")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        NSApp.setActivationPolicy(.accessory)
        startAccessibilityPoller()
    }

    private func startAccessibilityPoller() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var elapsed = 0.0
            while elapsed < 300 {
                Thread.sleep(forTimeInterval: 0.5)
                elapsed += 0.5
                guard self != nil else { return }
                if AXIsProcessTrusted() {
                    DispatchQueue.main.async { self?.restartApp() }
                    return
                }
            }
        }
    }

    private func restartApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Berechtigung erteilt"
        alert.informativeText = "Jellyfish muss neu gestartet werden, damit die Änderungen wirksam werden."
        alert.addButton(withTitle: "Jetzt neu starten")
        alert.runModal()

        let quoted = "'" + Bundle.main.bundleURL.path
            .replacingOccurrences(of: "'", with: "'\\''") + "'"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5 && open \(quoted)"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        NSApp.terminate(nil)
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
