import Cocoa
import Foundation

struct GitHubReleaseInfo: Decodable {
    let tagName: String
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
    }

    var versionString: String {
        tagName.replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
    }

    var version: AppVersion {
        AppVersion(versionString)
    }
}

extension AppController {
    func setupAutomaticUpdateChecks() {
        releaseCheckTimer?.invalidate()
        releaseCheckTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdates(userInitiated: false)
        }
        checkForUpdates(userInitiated: false)
    }

    func refreshUpdateMenuItem() {
        guard let menuItem = checkForUpdatesMenuItem else { return }

        if isCheckingForUpdates {
            menuItem.title = "Checking for Updates..."
            menuItem.isEnabled = false
        } else if let release = latestAvailableRelease {
            menuItem.title = "View \(release.versionString)"
            menuItem.isEnabled = true
        } else {
            menuItem.title = "Check for Updates"
            menuItem.isEnabled = true
        }
    }

    @objc func showAboutWindow() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }

        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func handleUpdatesMenuAction() {
        if let release = latestAvailableRelease {
            openReleasePage(for: release)
        } else {
            checkForUpdates(userInitiated: true)
        }
    }

    func checkForUpdates(userInitiated: Bool) {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        refreshUpdateMenuItem()

        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            guard let self else { return }

            do {
                let release = try await self.fetchLatestRelease()
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    if release.version > AppVersion(AppMetadata.installedVersion) {
                        self.latestAvailableRelease = release
                        self.refreshUpdateMenuItem()

                        if self.lastNotifiedReleaseTag != release.tagName {
                            self.lastNotifiedReleaseTag = release.tagName
                            self.presentReleaseAlert(for: release)
                        } else if userInitiated {
                            self.openReleasePage(for: release)
                        }
                    } else {
                        self.latestAvailableRelease = nil
                        self.refreshUpdateMenuItem()
                        if userInitiated {
                            self.presentInfoAlert(
                                title: "You’re Up to Date",
                                message: "You’re already running Nacrelum \(AppMetadata.displayVersion)."
                            )
                        }
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.refreshUpdateMenuItem()
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.refreshUpdateMenuItem()
                    if userInitiated {
                        self.presentErrorAlert(
                            title: "Couldn’t Check for Updates",
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }
    }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: AppMetadata.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppMetadata.projectName)/\(AppMetadata.installedVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: AppMetadata.projectName,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "GitHub did not return a valid release response."]
            )
        }

        let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
        guard !release.draft, !release.prerelease else {
            throw NSError(
                domain: AppMetadata.projectName,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The latest GitHub release is not publicly available yet."]
            )
        }
        return release
    }

    func presentReleaseAlert(for release: GitHubReleaseInfo) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Available"
        alert.informativeText = "Nacrelum \(release.versionString) is available."
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openReleasePage(for: release)
        }
    }

    func openReleasePage(for release: GitHubReleaseInfo) {
        NSWorkspace.shared.open(release.htmlURL)
    }

    func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
