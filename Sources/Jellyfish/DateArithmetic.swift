import Cocoa

// MARK: - Unit

enum DateArithmeticUnit: String, CaseIterable {
    case year   = "Jahr"
    case month  = "Monat"
    case day    = "Tag"
    case hour   = "Stunde"
    case minute = "Minute"
    case second = "Sekunde"

    var calendarComponent: Calendar.Component {
        switch self {
        case .year:   return .year
        case .month:  return .month
        case .day:    return .day
        case .hour:   return .hour
        case .minute: return .minute
        case .second: return .second
        }
    }

    var menuLabel: String {
        switch self {
        case .year:   return "Jahr(e)"
        case .month:  return "Monat(e)"
        case .day:    return "Tag(e)"
        case .hour:   return "Stunde(n)"
        case .minute: return "Minute(n)"
        case .second: return "Sekunde(n)"
        }
    }
}

// MARK: - Placeholder resolution
// Format: {RECHNUNG|+1|Tag|TT.MM.JJJJ}  (signed amount | unit.rawValue | ph.displayName)

struct DateArithmetic {
    private static let tag = "{RECHNUNG|"

    static func resolve(in text: String, at date: Date = Date()) -> String {
        guard text.contains(tag) else { return text }
        guard let regex = try? NSRegularExpression(pattern: #"\{RECHNUNG\|([^}]+)\}"#) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let innerRange = Range(match.range(at: 1), in: result) else { continue }
            let parts = result[innerRange].split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let amount = Int(parts[0]),
                  let unit = DateArithmeticUnit(rawValue: parts[1]),
                  let ph = DatePlaceholder.allCases.first(where: { $0.displayName == parts[2] }),
                  let newDate = Calendar.current.date(byAdding: unit.calendarComponent, value: amount, to: date)
            else { continue }
            result.replaceSubrange(fullRange, with: ph.resolve(at: newDate))
        }
        return result
    }
}

// MARK: - Sheet

final class DateArithmeticSheetController: NSViewController {
    var onApply: ((String) -> Void)?

    private var signControl: NSSegmentedControl!
    private var amountField: NSTextField!
    private var amountStepper: NSStepper!
    private var unitPopup: NSPopUpButton!
    private var formatPopup: NSPopUpButton!
    private var previewLabel: NSTextField!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 196))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        updatePreview()
    }

    private func buildUI() {
        let title = NSTextField(labelWithString: "Datumsrechnung")
        title.font = NSFont.boldSystemFont(ofSize: 14)
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)

        signControl = NSSegmentedControl(labels: ["+", "−"], trackingMode: .selectOne,
                                         target: self, action: #selector(valueChanged))
        signControl.selectedSegment = 0
        signControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signControl)

        amountField = NSTextField()
        amountField.stringValue = "1"
        amountField.translatesAutoresizingMaskIntoConstraints = false
        amountField.delegate = self
        view.addSubview(amountField)

        amountStepper = NSStepper()
        amountStepper.intValue = 1
        amountStepper.minValue = 1
        amountStepper.maxValue = 9999
        amountStepper.target = self
        amountStepper.action = #selector(stepperChanged(_:))
        amountStepper.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(amountStepper)

        unitPopup = NSPopUpButton()
        for unit in DateArithmeticUnit.allCases {
            unitPopup.addItem(withTitle: unit.menuLabel)
            unitPopup.lastItem?.representedObject = unit
        }
        unitPopup.target = self
        unitPopup.action = #selector(valueChanged)
        unitPopup.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(unitPopup)

        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.font = NSFont.systemFont(ofSize: 12)
        formatLabel.textColor = .secondaryLabelColor
        formatLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formatLabel)

        formatPopup = NSPopUpButton()
        let now = Date()
        for ph in DatePlaceholder.allCases {
            let preview = ph.resolve(at: now)
            formatPopup.addItem(withTitle: "\(ph.displayName)   →   \(preview)")
            formatPopup.lastItem?.representedObject = ph
        }
        formatPopup.target = self
        formatPopup.action = #selector(valueChanged)
        formatPopup.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formatPopup)

        let previewTitleLabel = NSTextField(labelWithString: "Vorschau:")
        previewTitleLabel.font = NSFont.systemFont(ofSize: 12)
        previewTitleLabel.textColor = .secondaryLabelColor
        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewTitleLabel)

        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewLabel)

        let cancelButton = NSButton(title: "Abbrechen", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let insertButton = NSButton(title: "Einfügen", target: self, action: #selector(insert))
        insertButton.bezelStyle = .rounded
        insertButton.keyEquivalent = "\r"
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(insertButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            signControl.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            signControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            amountField.centerYAnchor.constraint(equalTo: signControl.centerYAnchor),
            amountField.leadingAnchor.constraint(equalTo: signControl.trailingAnchor, constant: 8),
            amountField.widthAnchor.constraint(equalToConstant: 56),

            amountStepper.centerYAnchor.constraint(equalTo: signControl.centerYAnchor),
            amountStepper.leadingAnchor.constraint(equalTo: amountField.trailingAnchor, constant: 2),

            unitPopup.centerYAnchor.constraint(equalTo: signControl.centerYAnchor),
            unitPopup.leadingAnchor.constraint(equalTo: amountStepper.trailingAnchor, constant: 8),
            unitPopup.widthAnchor.constraint(equalToConstant: 140),

            formatLabel.topAnchor.constraint(equalTo: signControl.bottomAnchor, constant: 14),
            formatLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            formatPopup.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatPopup.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 8),
            formatPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            previewTitleLabel.topAnchor.constraint(equalTo: formatLabel.bottomAnchor, constant: 14),
            previewTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            previewLabel.centerYAnchor.constraint(equalTo: previewTitleLabel.centerYAnchor),
            previewLabel.leadingAnchor.constraint(equalTo: previewTitleLabel.trailingAnchor, constant: 8),
            previewLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            insertButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            insertButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelButton.centerYAnchor.constraint(equalTo: insertButton.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: insertButton.leadingAnchor, constant: -8),
        ])
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        amountField.intValue = sender.intValue
        updatePreview()
    }

    @objc private func valueChanged() {
        updatePreview()
    }

    private func buildPlaceholder() -> String? {
        let sign = signControl.selectedSegment == 0 ? "+" : "-"
        guard let n = Int(amountField.stringValue), n > 0 else { return nil }
        let amount = sign == "-" ? -n : n
        guard let unit = unitPopup.selectedItem?.representedObject as? DateArithmeticUnit,
              let ph = formatPopup.selectedItem?.representedObject as? DatePlaceholder else { return nil }
        let prefix = amount >= 0 ? "+" : ""
        return "{RECHNUNG|\(prefix)\(amount)|\(unit.rawValue)|\(ph.displayName)}"
    }

    private func updatePreview() {
        guard let placeholder = buildPlaceholder() else { previewLabel.stringValue = ""; return }
        previewLabel.stringValue = DateArithmetic.resolve(in: placeholder)
    }

    @objc private func insert() {
        guard let placeholder = buildPlaceholder() else { return }
        dismiss(nil)
        onApply?(placeholder)
    }

    @objc private func cancel() {
        dismiss(nil)
    }
}

extension DateArithmeticSheetController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === amountField else { return }
        if let n = Int(field.stringValue), n > 0 { amountStepper.intValue = Int32(n) }
        updatePreview()
    }
}
