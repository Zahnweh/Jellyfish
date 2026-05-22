import Cocoa

final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private weak var loginItemCheckbox: NSButton?

    func show() {
        if window == nil { buildWindow() }
        loginItemCheckbox?.state = LoginItemManager.isEnabled ? .on : .off
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let pad: CGFloat = 24

        let sectionLabel = NSTextField(labelWithString: "Allgemein")
        sectionLabel.font = NSFont.boldSystemFont(ofSize: 13)
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSButton(checkboxWithTitle: "Beim Login starten",
                                target: self,
                                action: #selector(toggleLoginItem(_:)))
        checkbox.state = LoginItemManager.isEnabled ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        loginItemCheckbox = checkbox

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sectionLabel)
        content.addSubview(checkbox)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: content.topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sectionLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            checkbox.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 12),
            checkbox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            checkbox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            checkbox.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let wrapper = NSView()
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: pad),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -pad),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -pad),
            content.widthAnchor.constraint(equalToConstant: 280),
        ])

        wrapper.frame = CGRect(x: 0, y: 0, width: 328, height: 200)
        wrapper.layoutSubtreeIfNeeded()
        let h = content.fittingSize.height + pad * 2

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 328, height: h),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Einstellungen"
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = wrapper
        window = w
    }

    @objc private func toggleLoginItem(_ sender: NSButton) {
        if sender.state == .on {
            LoginItemManager.enable()
        } else {
            LoginItemManager.disable()
        }
    }
}
