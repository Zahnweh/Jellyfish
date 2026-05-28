import Cocoa

final class OptionalBlockSheetController: NSViewController {
    var onApply: ((String) -> Void)?
    var selectedText: String = ""

    private var textView: NSTextView!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 185))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        textView.string = selectedText
    }

    // MARK: - UI

    private func buildUI() {
        let pad: CGFloat = 16

        let titleLabel = NSTextField(labelWithString: "Optionaler Block")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let textRowLabel = NSTextField(labelWithString: "Text:")
        textRowLabel.font = NSFont.systemFont(ofSize: 13)
        textRowLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textRowLabel)

        textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

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

            textRowLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            textRowLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            scrollView.topAnchor.constraint(equalTo: textRowLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            scrollView.heightAnchor.constraint(equalToConstant: 90),

            okButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 14),
            okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            okButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func cancel() {
        presentingViewController?.dismiss(self)
    }

    @objc private func applyBlock() {
        let text = textView.string.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            textView.window?.makeFirstResponder(textView)
            return
        }
        let result = "{optional:\(text)}{/optional}"
        presentingViewController?.dismiss(self)
        onApply?(result)
    }
}
