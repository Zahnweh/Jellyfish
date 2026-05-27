import AppKit
import UniformTypeIdentifiers

// MARK: - CSV Parser

enum CSVParser {
    /// Parst einen CSV-String (RFC 4180-kompatibel, mit BOM-Unterstützung) in Zeilen.
    static func parse(_ raw: String) -> [[String]] {
        // BOM entfernen
        let text = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw

        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    // Escaped quote ("") oder Ende des Feldes
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(field)
                    field = ""
                case "\r":
                    break // Windows-Zeilenende ignorieren
                case "\n":
                    currentRow.append(field)
                    field = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                default:
                    field.append(c)
                }
            }
            i += 1
        }
        // Letzte Zeile
        currentRow.append(field)
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }
        return rows
    }
}

// MARK: - CSV Writer

enum CSVWriter {
    static func write(snippets: [Snippet]) -> String {
        snippets.map { s in
            "\(quoted(s.trigger)),\(quoted(s.expansion)),\(quoted(s.name))"
        }.joined(separator: "\n")
    }

    private static func quoted(_ s: String) -> String {
        "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

// MARK: - TextExpander-Konverter

enum TextExpanderConverter {
    /// Wandelt TextExpander-Syntax in Jellyfish-Syntax um.
    static func convert(_ text: String) -> String {
        var result = text

        // %fillpopup:name=NAME:default=OPT1:OPT2:...%
        // %fillpopup:name=NAME:OPT1:OPT2:...%  (ohne "default=")
        // → {AUSWAHL:OPT1|OPT2|...}
        let pattern = #"%fillpopup:name=[^:]+:(?:default=)?([^%]+)%"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                let optStr = ns.substring(with: match.range(at: 1))
                let options = optStr.components(separatedBy: ":").joined(separator: "|")
                result = ns.replacingCharacters(in: match.range, with: "{AUSWAHL:\(options)}")
                // ns ist nach replace veraltet – neu wrappen
            }
            // Nochmal sauber mit frischem NSString (wegen reversed-Ersetzungen)
            result = applyFillpopup(result)
        }

        // %clipboard → {ZWISCHENABLAGE}
        result = result.replacingOccurrences(of: "%clipboard", with: "{ZWISCHENABLAGE}")

        // %% → % (TextExpander-Escape für Prozentzeichen, nach fillpopup-Ersetzung)
        result = result.replacingOccurrences(of: "%%", with: "%")

        return result
    }

    private static func applyFillpopup(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"%fillpopup:name=[^:]+:(?:default=)?([^%]+)%"#) else {
            return input
        }
        var result = input
        while let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)) {
            let ns = result as NSString
            let optStr = ns.substring(with: match.range(at: 1))
            let options = optStr.components(separatedBy: ":").joined(separator: "|")
            result = ns.replacingCharacters(in: match.range, with: "{AUSWAHL:\(options)}")
        }
        return result
    }
}

// MARK: - Import/Export UI

class ImportExportController {

    // MARK: Import

    static func runImport(convertTextExpander: Bool,
                          window: NSWindow,
                          onComplete: @escaping (UUID?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "csv") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = convertTextExpander ? "TextExpander-CSV importieren" : "CSV importieren"
        panel.prompt = "Importieren"

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            processImport(url: url,
                          convertTextExpander: convertTextExpander,
                          window: window,
                          onComplete: onComplete)
        }
    }

    private static func processImport(url: URL,
                                      convertTextExpander: Bool,
                                      window: NSWindow,
                                      onComplete: @escaping (UUID?) -> Void) {
        // Datei einlesen (UTF-8 mit/ohne BOM, Fallback Windows-1252)
        guard let raw = (try? String(contentsOf: url, encoding: .utf8))
                     ?? (try? String(contentsOf: url, encoding: .windowsCP1252)) else {
            alert("Fehler", "Die Datei konnte nicht gelesen werden.", window: window)
            return
        }

        let rows = CSVParser.parse(raw)
        var parsed: [(trigger: String, expansion: String, name: String)] = []

        for row in rows {
            guard row.count >= 2 else { continue }
            let trigger = row[0].trimmingCharacters(in: .whitespaces)
            var expansion = row[1]
            let name = row.count >= 3 ? row[2] : ""
            guard !trigger.isEmpty || !expansion.isEmpty else { continue }
            if convertTextExpander {
                expansion = TextExpanderConverter.convert(expansion)
            }
            parsed.append((trigger, expansion, name))
        }

        guard !parsed.isEmpty else {
            alert("Nichts importiert", "Keine gültigen Bausteine in der Datei gefunden.", window: window)
            return
        }

        // Vorgeschlagener Ordnername = Dateiname ohne Endung
        let suggestedName = url.deletingPathExtension().lastPathComponent

        showFolderSheet(snippets: parsed,
                        suggestedFolderName: suggestedName,
                        window: window,
                        onComplete: onComplete)
    }

    private static func showFolderSheet(
        snippets: [(trigger: String, expansion: String, name: String)],
        suggestedFolderName: String,
        window: NSWindow,
        onComplete: @escaping (UUID?) -> Void
    ) {
        let folders = SnippetManager.shared.folders

        let alertBox = NSAlert()
        alertBox.messageText = "\(snippets.count) Bausteine importieren"
        alertBox.informativeText = "In welchen Ordner sollen die Bausteine importiert werden?"
        alertBox.addButton(withTitle: "Importieren")
        alertBox.addButton(withTitle: "Abbrechen")

        // Accessory: Ordner-Auswahl
        let accessoryWidth: CGFloat = 320
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: 28))
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 1, width: accessoryWidth, height: 26))
        popup.addItem(withTitle: "Neuer Ordner: \"\(suggestedFolderName)\"")
        if !folders.isEmpty {
            popup.menu?.addItem(.separator())
            for folder in folders {
                popup.addItem(withTitle: folder.name)
            }
        }
        accessory.addSubview(popup)
        alertBox.accessoryView = accessory

        alertBox.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }

            // Zielordner bestimmen
            let selectedIndex = popup.indexOfSelectedItem
            let targetFolderID: UUID?

            if selectedIndex == 0 {
                // Neuen Ordner anlegen
                let newFolder = SnippetManager.shared.addFolder(name: suggestedFolderName, parentId: nil)
                targetFolderID = newFolder.id
            } else {
                // Separator hat Index 1 → Ordner beginnen bei Index 2
                let folderIndex = selectedIndex - 2
                targetFolderID = (folderIndex >= 0 && folderIndex < folders.count)
                    ? folders[folderIndex].id
                    : nil
            }

            // Bausteine importieren (immer neue Einträge)
            let newSnippets = snippets.map { s in
                Snippet(id: UUID(), trigger: s.trigger, expansion: s.expansion,
                        name: s.name, folderId: targetFolderID)
            }
            SnippetManager.shared.batchAdd(newSnippets)

            onComplete(targetFolderID)

            alert("Import abgeschlossen",
                  "\(newSnippets.count) Bausteine wurden erfolgreich importiert.",
                  window: window)
        }
    }

    // MARK: Export

    static func runExport(snippets: [Snippet],
                          suggestedName: String,
                          window: NSWindow) {
        guard !snippets.isEmpty else {
            alert("Nichts zu exportieren", "Es sind keine Bausteine zum Exportieren vorhanden.", window: window)
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "csv") ?? .data]
        panel.nameFieldStringValue = "\(suggestedName).csv"
        panel.title = "Bausteine exportieren"
        panel.prompt = "Exportieren"

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let content = CSVWriter.write(snippets: snippets)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                alert("Fehler", "Die Datei konnte nicht gespeichert werden:\n\(error.localizedDescription)",
                      window: window)
            }
        }
    }

    // MARK: Helpers

    private static func alert(_ title: String, _ message: String, window: NSWindow) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.beginSheetModal(for: window)
    }
}
