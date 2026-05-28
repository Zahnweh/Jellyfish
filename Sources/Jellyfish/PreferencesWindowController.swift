import Cocoa

final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private weak var loginItemCheckbox: NSButton?
    private weak var syncPathLabel: NSTextField?
    private weak var syncResetButton: NSButton?
    private weak var teamPathLabel: NSTextField?
    private weak var teamResetButton: NSButton?

    func show() {
        if window == nil { buildWindow() }
        loginItemCheckbox?.state = LoginItemManager.isEnabled ? .on : .off
        updateSyncUI()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateSyncUI() {
        if let url = SnippetManager.shared.syncFolderURL {
            syncPathLabel?.stringValue = url.path
            syncPathLabel?.textColor = .labelColor
            syncResetButton?.isHidden = false
        } else {
            syncPathLabel?.stringValue = "Lokal (kein Sync)"
            syncPathLabel?.textColor = .secondaryLabelColor
            syncResetButton?.isHidden = true
        }

        if let url = SnippetManager.shared.teamFolderURL {
            teamPathLabel?.stringValue = url.path
            teamPathLabel?.textColor = .labelColor
            teamResetButton?.isHidden = false
        } else {
            teamPathLabel?.stringValue = "Nicht konfiguriert"
            teamPathLabel?.textColor = .secondaryLabelColor
            teamResetButton?.isHidden = true
        }
    }

    private func makeSectionLabel(_ title: String) -> NSTextField {
        let l = NSTextField(labelWithString: title)
        l.font = NSFont.boldSystemFont(ofSize: 13)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeHintLabel(_ text: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makePathLabel() -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        l.textColor = .secondaryLabelColor
        l.lineBreakMode = .byTruncatingMiddle
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func buildWindow() {
        let pad: CGFloat = 24

        // MARK: Allgemein

        let generalLabel = makeSectionLabel("Allgemein")

        let checkbox = NSButton(checkboxWithTitle: "Beim Login starten",
                                target: self,
                                action: #selector(toggleLoginItem(_:)))
        checkbox.state = LoginItemManager.isEnabled ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        loginItemCheckbox = checkbox

        // MARK: Persönlicher Sync

        let syncLabel = makeSectionLabel("Persönlicher Sync")
        let syncHint = makeHintLabel(
            "Wähle einen Ordner in iCloud Drive, Dropbox o. ä., um deine Snippets " +
            "auf all deinen eigenen Geräten zu synchronisieren.")

        let syncPath = makePathLabel()
        syncPathLabel = syncPath

        let syncChoose = NSButton(title: "Ordner wählen…", target: self,
                                  action: #selector(chooseSyncFolder))
        syncChoose.bezelStyle = .rounded
        syncChoose.translatesAutoresizingMaskIntoConstraints = false

        let syncReset = NSButton(title: "Lokal zurücksetzen", target: self,
                                 action: #selector(resetSyncFolder))
        syncReset.bezelStyle = .rounded
        syncReset.translatesAutoresizingMaskIntoConstraints = false
        syncReset.isHidden = true
        syncResetButton = syncReset

        let syncButtons = NSStackView(views: [syncChoose, syncReset])
        syncButtons.orientation = .horizontal
        syncButtons.spacing = 8
        syncButtons.translatesAutoresizingMaskIntoConstraints = false

        // MARK: Team-Sync

        let teamLabel = makeSectionLabel("Team-Sync")
        let teamHint = makeHintLabel(
            "Wähle einen gemeinsamen Ordner (z. B. ein geteilter Dropbox-Ordner), " +
            "um einzelne Snippet-Ordner mit deinem Team zu teilen. " +
            "Ordner als geteilt markieren: Rechtsklick in der Sidebar → \"Mit Team teilen\".")

        let teamPath = makePathLabel()
        teamPathLabel = teamPath

        let teamChoose = NSButton(title: "Ordner wählen…", target: self,
                                  action: #selector(chooseTeamFolder))
        teamChoose.bezelStyle = .rounded
        teamChoose.translatesAutoresizingMaskIntoConstraints = false

        let teamReset = NSButton(title: "Team-Sync entfernen", target: self,
                                 action: #selector(resetTeamFolder))
        teamReset.bezelStyle = .rounded
        teamReset.translatesAutoresizingMaskIntoConstraints = false
        teamReset.isHidden = true
        teamResetButton = teamReset

        let teamButtons = NSStackView(views: [teamChoose, teamReset])
        teamButtons.orientation = .horizontal
        teamButtons.spacing = 8
        teamButtons.translatesAutoresizingMaskIntoConstraints = false

        // MARK: Layout

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        for v in [generalLabel, checkbox,
                  syncLabel, syncHint, syncPath, syncButtons,
                  teamLabel, teamHint, teamPath, teamButtons] {
            content.addSubview(v)
        }

        NSLayoutConstraint.activate([
            generalLabel.topAnchor.constraint(equalTo: content.topAnchor),
            generalLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            generalLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            checkbox.topAnchor.constraint(equalTo: generalLabel.bottomAnchor, constant: 12),
            checkbox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            checkbox.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            syncLabel.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 24),
            syncLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            syncLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            syncHint.topAnchor.constraint(equalTo: syncLabel.bottomAnchor, constant: 8),
            syncHint.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            syncHint.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            syncPath.topAnchor.constraint(equalTo: syncHint.bottomAnchor, constant: 10),
            syncPath.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            syncPath.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            syncButtons.topAnchor.constraint(equalTo: syncPath.bottomAnchor, constant: 10),
            syncButtons.leadingAnchor.constraint(equalTo: content.leadingAnchor),

            teamLabel.topAnchor.constraint(equalTo: syncButtons.bottomAnchor, constant: 24),
            teamLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            teamLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            teamHint.topAnchor.constraint(equalTo: teamLabel.bottomAnchor, constant: 8),
            teamHint.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            teamHint.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            teamPath.topAnchor.constraint(equalTo: teamHint.bottomAnchor, constant: 10),
            teamPath.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            teamPath.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            teamButtons.topAnchor.constraint(equalTo: teamPath.bottomAnchor, constant: 10),
            teamButtons.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            teamButtons.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let wrapper = NSView()
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: pad),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -pad),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -pad),
            content.widthAnchor.constraint(equalToConstant: 340),
        ])

        wrapper.frame = CGRect(x: 0, y: 0, width: 388, height: 600)
        wrapper.layoutSubtreeIfNeeded()
        let h = content.fittingSize.height + pad * 2

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 388, height: h),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Einstellungen"
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = wrapper
        window = w

        updateSyncUI()
    }

    @objc private func toggleLoginItem(_ sender: NSButton) {
        LoginItemManager.isEnabled ? LoginItemManager.disable() : LoginItemManager.enable()
    }

    // MARK: - Personal sync actions

    @objc private func chooseSyncFolder() {
        openFolderPanel(
            message: "Wähle den Ordner, in dem Jellyfish deine eigenen Snippets synchronisiert."
        ) { [weak self] url in
            if url.standardizedFileURL == SnippetManager.shared.teamFolderURL?.standardizedFileURL {
                self?.showConflictAlert(
                    "Persönlicher Sync-Ordner kann nicht der Team-Ordner sein",
                    info: "Wähle einen anderen Ordner für deinen persönlichen Sync, " +
                          "sonst überschreiben sich persönliche und geteilte Snippets gegenseitig.")
                return
            }
            SnippetManager.shared.setSyncFolder(url)
            self?.updateSyncUI()
        }
    }

    @objc private func resetSyncFolder() {
        confirmReset(
            title: "Persönlichen Sync-Ordner entfernen?",
            info: "Jellyfish speichert deine Snippets wieder lokal. Die Daten im Sync-Ordner bleiben erhalten."
        ) { [weak self] in
            SnippetManager.shared.setSyncFolder(nil)
            self?.updateSyncUI()
        }
    }

    // MARK: - Team sync actions

    @objc private func chooseTeamFolder() {
        openFolderPanel(
            message: "Wähle den gemeinsamen Ordner für Team-Snippets (z. B. ein geteilter Dropbox-Ordner)."
        ) { [weak self] url in
            if url.standardizedFileURL == SnippetManager.shared.syncFolderURL?.standardizedFileURL {
                self?.showConflictAlert(
                    "Team-Ordner kann nicht der persönliche Sync-Ordner sein",
                    info: "Wähle einen anderen Ordner für den Team-Sync, " +
                          "sonst überschreiben sich persönliche und geteilte Snippets gegenseitig.")
                return
            }
            SnippetManager.shared.setTeamFolder(url)
            self?.updateSyncUI()
            NotificationCenter.default.post(name: .snippetsDidReloadExternally, object: nil)
        }
    }

    @objc private func resetTeamFolder() {
        confirmReset(
            title: "Team-Sync entfernen?",
            info: "Team-Ordner werden wieder zu persönlichen Ordnern. Die Daten im Team-Ordner bleiben erhalten."
        ) { [weak self] in
            SnippetManager.shared.setTeamFolder(nil)
            self?.updateSyncUI()
            NotificationCenter.default.post(name: .snippetsDidReloadExternally, object: nil)
        }
    }

    // MARK: - Helpers

    private func showConflictAlert(_ title: String, info: String) {
        guard let w = window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: w) { _ in }
    }

    private func openFolderPanel(message: String, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Ordner wählen"
        panel.message = message
        guard let w = window else { return }
        panel.beginSheetModal(for: w) { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
    }

    private func confirmReset(title: String, info: String, completion: @escaping () -> Void) {
        guard let w = window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Entfernen")
        alert.addButton(withTitle: "Abbrechen")
        alert.beginSheetModal(for: w) { response in
            guard response == .alertFirstButtonReturn else { return }
            completion()
        }
    }
}
