import Cocoa

final class OptionalBlockSheetController: NSViewController {
    var onApply: ((String) -> Void)?
    var selectedText: String = ""
    var expansionText: String = ""

    private var labelField: NSTextField!
    private var groupBindingToggle: NSButton!
    private var groupSection: NSView!
    private var groupField: NSTextField!
    private var optionsLabel: NSTextField!
    private var optionsStack: NSStackView!
    private var noGroupHint: NSTextField!
    private var optionCheckboxes: [NSButton] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        updateGroupSectionVisibility(animated: false)
    }

    // MARK: - UI

    private func buildUI() {
        let pad: CGFloat = 16
        let labelColumnW: CGFloat = 60

        // Title
        let titleLabel = NSTextField(labelWithString: "Optionaler Block")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Label row
        let labelRowLabel = NSTextField(labelWithString: "Label:")
        labelRowLabel.font = NSFont.systemFont(ofSize: 13)
        labelRowLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelRowLabel)

        labelField = NSTextField()
        labelField.placeholderString = "z. B. Anhang"
        labelField.font = NSFont.systemFont(ofSize: 13)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelField)

        let labelHint = NSTextField(labelWithString: "Wird im Auswahl-Dialog als Checkbox-Label angezeigt")
        labelHint.font = NSFont.systemFont(ofSize: 10)
        labelHint.textColor = .tertiaryLabelColor
        labelHint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelHint)

        // Group binding toggle
        groupBindingToggle = NSButton(checkboxWithTitle: "Mit Dropdown-Gruppe verknüpfen",
                                      target: self, action: #selector(toggleGroupBinding))
        groupBindingToggle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(groupBindingToggle)

        // Group section container
        groupSection = NSView()
        groupSection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(groupSection)

        let groupRowLabel = NSTextField(labelWithString: "Gruppe:")
        groupRowLabel.font = NSFont.systemFont(ofSize: 13)
        groupRowLabel.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(groupRowLabel)

        groupField = NSTextField()
        groupField.placeholderString = "z. B. 1"
        groupField.font = NSFont.systemFont(ofSize: 13)
        groupField.delegate = self
        groupField.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(groupField)

        let groupHint = NSTextField(labelWithString: "Gleiche Nummer wie das verknüpfte Dropdown")
        groupHint.font = NSFont.systemFont(ofSize: 10)
        groupHint.textColor = .tertiaryLabelColor
        groupHint.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(groupHint)

        optionsLabel = NSTextField(labelWithString: "Sichtbar bei Auswahl:")
        optionsLabel.font = NSFont.systemFont(ofSize: 12)
        optionsLabel.textColor = .secondaryLabelColor
        optionsLabel.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(optionsLabel)

        optionsStack = NSStackView()
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 4
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(optionsStack)

        noGroupHint = NSTextField(labelWithString: "Gruppe eingeben, um Optionen anzuzeigen")
        noGroupHint.font = NSFont.systemFont(ofSize: 11)
        noGroupHint.textColor = .tertiaryLabelColor
        noGroupHint.translatesAutoresizingMaskIntoConstraints = false
        groupSection.addSubview(noGroupHint)

        NSLayoutConstraint.activate([
            groupRowLabel.topAnchor.constraint(equalTo: groupSection.topAnchor),
            groupRowLabel.leadingAnchor.constraint(equalTo: groupSection.leadingAnchor),
            groupRowLabel.widthAnchor.constraint(equalToConstant: labelColumnW),

            groupField.centerYAnchor.constraint(equalTo: groupRowLabel.centerYAnchor),
            groupField.leadingAnchor.constraint(equalTo: groupRowLabel.trailingAnchor, constant: 8),
            groupField.widthAnchor.constraint(equalToConstant: 60),

            groupHint.centerYAnchor.constraint(equalTo: groupRowLabel.centerYAnchor),
            groupHint.leadingAnchor.constraint(equalTo: groupField.trailingAnchor, constant: 8),
            groupHint.trailingAnchor.constraint(lessThanOrEqualTo: groupSection.trailingAnchor),

            optionsLabel.topAnchor.constraint(equalTo: groupRowLabel.bottomAnchor, constant: 12),
            optionsLabel.leadingAnchor.constraint(equalTo: groupSection.leadingAnchor),

            optionsStack.topAnchor.constraint(equalTo: optionsLabel.bottomAnchor, constant: 6),
            optionsStack.leadingAnchor.constraint(equalTo: groupSection.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: groupSection.trailingAnchor),
            optionsStack.bottomAnchor.constraint(equalTo: groupSection.bottomAnchor),

            noGroupHint.topAnchor.constraint(equalTo: optionsLabel.bottomAnchor, constant: 6),
            noGroupHint.leadingAnchor.constraint(equalTo: groupSection.leadingAnchor),
        ])

        // Buttons
        let cancelButton = NSButton(title: "Abbrechen", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let okButton = NSButton(title: "Einfügen", target: self, action: #selector(applyBlock))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(okButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            labelRowLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            labelRowLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            labelRowLabel.widthAnchor.constraint(equalToConstant: labelColumnW),

            labelField.centerYAnchor.constraint(equalTo: labelRowLabel.centerYAnchor),
            labelField.leadingAnchor.constraint(equalTo: labelRowLabel.trailingAnchor, constant: 8),
            labelField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            labelHint.topAnchor.constraint(equalTo: labelField.bottomAnchor, constant: 3),
            labelHint.leadingAnchor.constraint(equalTo: labelField.leadingAnchor),
            labelHint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            groupBindingToggle.topAnchor.constraint(equalTo: labelHint.bottomAnchor, constant: 14),
            groupBindingToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            groupSection.topAnchor.constraint(equalTo: groupBindingToggle.bottomAnchor, constant: 10),
            groupSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            groupSection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            okButton.topAnchor.constraint(equalTo: groupSection.bottomAnchor, constant: 16),
            okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            okButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func toggleGroupBinding() {
        updateGroupSectionVisibility(animated: true)
    }

    @objc private func cancel() {
        presentingViewController?.dismiss(self)
    }

    @objc private func applyBlock() {
        let label = labelField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else {
            labelField.becomeFirstResponder()
            return
        }

        let header: String
        if groupBindingToggle.state == .on,
           let groupId = Int(groupField.stringValue.trimmingCharacters(in: .whitespaces)) {
            let checkedIndices = optionCheckboxes.enumerated()
                .filter { $0.element.state == .on }
                .map { String($0.offset) }
            let indicesStr = checkedIndices.joined(separator: ",")
            header = "G\(groupId):\(indicesStr):\(label)"
        } else {
            header = label
        }

        let result = "{optional:\(header)}\(selectedText){/optional}"
        presentingViewController?.dismiss(self)
        onApply?(result)
    }

    // MARK: - Helpers

    private func updateGroupSectionVisibility(animated: Bool) {
        let isGroupBound = groupBindingToggle.state == .on
        groupSection.isHidden = !isGroupBound
        if isGroupBound && optionCheckboxes.isEmpty {
            reloadOptionsForCurrentGroup()
        }
        resizeSheet(animated: animated)
    }

    private func reloadOptionsForCurrentGroup() {
        let groupIdStr = groupField.stringValue.trimmingCharacters(in: .whitespaces)
        optionCheckboxes.forEach { $0.removeFromSuperview() }
        optionCheckboxes = []
        optionsStack.arrangedSubviews.forEach { optionsStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        guard let groupId = Int(groupIdStr) else {
            noGroupHint.isHidden = false
            optionsLabel.isHidden = false
            resizeSheet(animated: true)
            return
        }
        noGroupHint.isHidden = true
        optionsLabel.isHidden = false

        let dropdowns = DropdownPlaceholder.parse(in: expansionText)
        let matchingDropdown = dropdowns.first(where: { $0.groupId == groupId })
        let options = matchingDropdown?.options ?? []

        if options.isEmpty {
            let hint = NSTextField(labelWithString: "Keine Dropdown-Gruppe \(groupId) in diesem Textbaustein gefunden")
            hint.font = NSFont.systemFont(ofSize: 11)
            hint.textColor = .secondaryLabelColor
            optionsStack.addArrangedSubview(hint)
        } else {
            for (i, option) in options.enumerated() {
                let cb = NSButton(checkboxWithTitle: "\(i + 1). \(option)", target: nil, action: nil)
                cb.state = .on
                cb.font = NSFont.systemFont(ofSize: 12)
                optionsStack.addArrangedSubview(cb)
                optionCheckboxes.append(cb)
            }
        }
        resizeSheet(animated: true)
    }

    private func resizeSheet(animated: Bool) {
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        let newSize = NSSize(width: max(fitting.width, 360), height: fitting.height)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.allowsImplicitAnimation = true
                preferredContentSize = newSize
                view.frame.size = newSize
            }
        } else {
            preferredContentSize = newSize
            view.frame.size = newSize
        }
    }
}

// MARK: - NSTextFieldDelegate

extension OptionalBlockSheetController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField, tf === groupField else { return }
        reloadOptionsForCurrentGroup()
    }
}
