import Cocoa

final class AboutWindowController: NSObject {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil { buildWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let pad: CGFloat = 24

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "Jellyfish")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 17)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "Version \(Updater.version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        let updateBtn = NSButton(title: "Nach Updates suchen",
                                 target: self,
                                 action: #selector(checkUpdates))
        updateBtn.bezelStyle = .rounded
        updateBtn.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(icon)
        content.addSubview(nameLabel)
        content.addSubview(versionLabel)
        content.addSubview(updateBtn)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: content.topAnchor),
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            versionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            versionLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            updateBtn.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 16),
            updateBtn.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            updateBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let wrapper = NSView()
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: pad),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -pad),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -pad),
            content.widthAnchor.constraint(equalToConstant: 220),
        ])

        wrapper.frame = CGRect(x: 0, y: 0, width: 268, height: 400)
        wrapper.layoutSubtreeIfNeeded()
        let h = content.fittingSize.height + pad * 2

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 268, height: h),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Über Jellyfish"
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = wrapper
        window = w
    }

    @objc private func checkUpdates() {
        Updater.checkManually()
    }
}
