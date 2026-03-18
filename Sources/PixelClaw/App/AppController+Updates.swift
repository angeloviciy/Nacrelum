import Cocoa

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

        switch appUpdateState {
        case .idle:
            menuItem.title = "Check for Updates"
            menuItem.isEnabled = true
        case .checking:
            menuItem.title = "Checking for Updates..."
            menuItem.isEnabled = false
        case let .updateAvailable(release):
            menuItem.title = "Update to \(release.versionString)"
            menuItem.isEnabled = true
        case let .downloading(release):
            menuItem.title = "Downloading \(release.versionString)..."
            menuItem.isEnabled = false
        case let .installing(release):
            menuItem.title = "Installing \(release.versionString)..."
            menuItem.isEnabled = false
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
        switch appUpdateState {
        case let .updateAvailable(release):
            installUpdate(release)
        case .idle:
            checkForUpdates(userInitiated: true)
        case .checking, .downloading, .installing:
            break
        }
    }

    func checkForUpdates(userInitiated: Bool) {
        if case .checking = appUpdateState { return }
        if case .downloading = appUpdateState { return }
        if case .installing = appUpdateState { return }

        appUpdateState = .checking
        refreshUpdateMenuItem()

        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await self.appUpdater.fetchLatestRelease()
                await MainActor.run {
                    if self.appUpdater.isNewer(release) {
                        self.appUpdateState = .updateAvailable(release)
                        self.refreshUpdateMenuItem()
                    } else {
                        self.appUpdateState = .idle
                        self.refreshUpdateMenuItem()
                        if userInitiated {
                            self.presentInfoAlert(
                                title: "You’re Up to Date",
                                message: "You’re already running PixelClaw \(AppMetadata.displayVersion)."
                            )
                        }
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.appUpdateState = .idle
                    self.refreshUpdateMenuItem()
                }
            } catch {
                await MainActor.run {
                    self.appUpdateState = .idle
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

    func installUpdate(_ release: GitHubRelease) {
        appUpdateState = .downloading(release)
        refreshUpdateMenuItem()

        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            guard let self else { return }
            do {
                let preparedAppURL = try await self.appUpdater.downloadAndPrepareUpdate(release)
                await MainActor.run {
                    self.appUpdateState = .installing(release)
                    self.refreshUpdateMenuItem()
                }
                try self.appUpdater.installPreparedApp(at: preparedAppURL)
                await MainActor.run {
                    self.exitApp()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.appUpdateState = .updateAvailable(release)
                    self.refreshUpdateMenuItem()
                }
            } catch {
                await MainActor.run {
                    self.appUpdateState = .updateAvailable(release)
                    self.refreshUpdateMenuItem()
                    self.presentErrorAlert(
                        title: "Couldn’t Install the Update",
                        message: error.localizedDescription
                    )
                }
            }
        }
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
