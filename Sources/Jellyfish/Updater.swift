import AppKit
import Foundation

enum Updater {

    static let version = "0.0.2"

    private static let apiURL = URL(string: "https://api.github.com/repos/Zahnweh/Jellyfish/releases/latest")!

    static func checkOnLaunch() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
            fetchLatestRelease { newVersion, url in
                guard let newVersion, let url else { return }
                DispatchQueue.main.async { promptUpdate(newVersion: newVersion, downloadURL: url) }
            }
        }
    }

    static func checkManually() {
        DispatchQueue.global(qos: .userInitiated).async {
            fetchLatestRelease { newVersion, url in
                DispatchQueue.main.async {
                    if let newVersion, let url {
                        promptUpdate(newVersion: newVersion, downloadURL: url)
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Kein Update verfügbar"
                        alert.informativeText = "Jellyfish \(version) ist bereits die neueste Version."
                        alert.runModal()
                    }
                }
            }
        }
    }

    // MARK: - Private

    private static func fetchLatestRelease(completion: @escaping (String?, URL?) -> Void) {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Jellyfish/\(version)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String,
                let assets = json["assets"] as? [[String: Any]],
                let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                let urlStr = dmg["browser_download_url"] as? String,
                let downloadURL = URL(string: urlStr)
            else { completion(nil, nil); return }

            let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if remote.compare(version, options: .numeric) == .orderedDescending {
                completion(remote, downloadURL)
            } else {
                completion(nil, nil)
            }
        }.resume()
    }

    private static func promptUpdate(newVersion: String, downloadURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Update verfügbar"
        alert.informativeText = "Jellyfish \(newVersion) ist verfügbar (installiert: \(version))."
        alert.addButton(withTitle: "Aktualisieren")
        alert.addButton(withTitle: "Später")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        downloadAndInstall(from: downloadURL)
    }

    private static func downloadAndInstall(from url: URL) {
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            guard let tempURL, error == nil else {
                DispatchQueue.main.async { showError("Download fehlgeschlagen.") }
                return
            }

            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            let dmg = tmp.appendingPathComponent("Jellyfish_update.dmg")
            let mnt = tmp.appendingPathComponent("Jellyfish_mnt_\(Int.random(in: 10000...99999))")
            let currentApp = Bundle.main.bundleURL

            do {
                try? FileManager.default.removeItem(at: dmg)
                try FileManager.default.moveItem(at: tempURL, to: dmg)

                let mountProc = Process()
                mountProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                mountProc.arguments = ["attach", "-noverify", "-noautoopen", "-mountpoint", mnt.path, dmg.path]
                mountProc.standardOutput = Pipe()
                mountProc.standardError = Pipe()
                try mountProc.run()
                mountProc.waitUntilExit()
                guard mountProc.terminationStatus == 0 else {
                    throw NSError(domain: "Updater", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "DMG konnte nicht gemountet werden."])
                }

                let newApp = mnt.appendingPathComponent("Jellyfish.app")

                let script = """
                #!/bin/bash
                sleep 2
                if [ -d \(q(newApp.path)) ]; then
                    rm -rf \(q(currentApp.path))
                    ditto \(q(newApp.path)) \(q(currentApp.path))
                    /usr/bin/xattr -dr com.apple.quarantine \(q(currentApp.path))
                fi
                hdiutil detach \(q(mnt.path)) 2>/dev/null
                rm -f \(q(dmg.path))
                open \(q(currentApp.path))
                """

                let scriptURL = tmp.appendingPathComponent("jellyfish_update.sh")
                try script.write(to: scriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                      ofItemAtPath: scriptURL.path)

                DispatchQueue.main.async {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
                    task.arguments = ["/bin/bash", scriptURL.path]
                    task.standardOutput = FileHandle.nullDevice
                    task.standardError = FileHandle.nullDevice
                    try? task.run()
                    NSApp.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async { showError(error.localizedDescription) }
            }
        }.resume()
    }

    private static func q(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update fehlgeschlagen"
        alert.informativeText = message
        alert.runModal()
    }
}
