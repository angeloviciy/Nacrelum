import Cocoa
import Foundation

enum AppUpdateState {
    case idle
    case checking
    case updateAvailable(GitHubRelease)
    case downloading(GitHubRelease)
    case installing(GitHubRelease)
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }

        var isZip: Bool { name.lowercased().hasSuffix(".zip") }
        var isDMG: Bool { name.lowercased().hasSuffix(".dmg") }
    }

    let tagName: String
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }

    var versionString: String {
        tagName.replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
    }

    var version: AppVersion {
        AppVersion(versionString)
    }

    func preferredAsset(appName: String) -> Asset? {
        let lowerAppName = appName.lowercased()
        let matching = assets.filter { $0.name.lowercased().contains(lowerAppName) }
        return preferredAsset(in: matching) ?? preferredAsset(in: assets)
    }

    private func preferredAsset(in assets: [Asset]) -> Asset? {
        assets.first(where: \.isZip) ?? assets.first(where: \.isDMG)
    }
}

enum AppUpdaterError: LocalizedError {
    case invalidResponse
    case noPublishedReleases
    case missingReleaseAsset
    case unsupportedAsset(String)
    case runningOutsideAppBundle
    case cannotPrepareInstalledApp
    case installScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid release response."
        case .noPublishedReleases:
            return "There are no published GitHub releases for PixelClaw yet."
        case .missingReleaseAsset:
            return "The latest GitHub release does not include a downloadable PixelClaw app."
        case let .unsupportedAsset(name):
            return "The release asset \(name) is not supported. Expected a .zip or .dmg file."
        case .runningOutsideAppBundle:
            return "Updates only work when PixelClaw is running from a writable .app bundle."
        case .cannotPrepareInstalledApp:
            return "The downloaded release did not contain a PixelClaw.app bundle."
        case let .installScriptFailed(message):
            return "The updater could not start the installer: \(message)"
        }
    }
}

final class AppUpdater {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: AppMetadata.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppMetadata.projectName)/\(AppMetadata.installedVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdaterError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            throw AppUpdaterError.noPublishedReleases
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdaterError.invalidResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.draft, !release.prerelease else {
            throw AppUpdaterError.invalidResponse
        }
        return release
    }

    func isNewer(_ release: GitHubRelease) -> Bool {
        release.version > AppVersion(AppMetadata.installedVersion)
    }

    func downloadAndPrepareUpdate(_ release: GitHubRelease) async throws -> URL {
        guard let asset = release.preferredAsset(appName: AppMetadata.projectName) else {
            throw AppUpdaterError.missingReleaseAsset
        }

        let (downloadedFile, _) = try await session.download(from: asset.browserDownloadURL)
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true, attributes: nil)

        let assetURL = workspace.appendingPathComponent(asset.name)
        try FileManager.default.moveItem(at: downloadedFile, to: assetURL)

        if asset.isZip {
            return try unpackZip(assetURL, in: workspace)
        }
        if asset.isDMG {
            return try copyAppFromDMG(assetURL, in: workspace)
        }

        throw AppUpdaterError.unsupportedAsset(asset.name)
    }

    func installPreparedApp(at preparedAppURL: URL) throws {
        let installedAppURL = Bundle.main.bundleURL.standardizedFileURL
        guard installedAppURL.pathExtension == "app" else {
            throw AppUpdaterError.runningOutsideAppBundle
        }

        let parentURL = installedAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parentURL.path) else {
            throw AppUpdaterError.runningOutsideAppBundle
        }

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("pixelclaw-install-\(UUID().uuidString).sh")
        let sourcePath = shellQuoted(preparedAppURL.path)
        let destinationPath = shellQuoted(installedAppURL.path)
        let script = """
        #!/bin/zsh
        set -euo pipefail
        src=\(sourcePath)
        dst=\(destinationPath)
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
          sleep 1
        done
        rm -rf "$dst"
        ditto "$src" "$dst"
        xattr -dr com.apple.quarantine "$dst" 2>/dev/null || true
        open "$dst"
        rm -f \(shellQuoted(scriptURL.path))
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]

        do {
            try process.run()
        } catch {
            throw AppUpdaterError.installScriptFailed(error.localizedDescription)
        }
    }

    private func unpackZip(_ zipURL: URL, in workspace: URL) throws -> URL {
        let outputURL = workspace.appendingPathComponent("unzipped", isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, outputURL.path]
        try run(process)

        return try findApp(in: outputURL)
    }

    private func copyAppFromDMG(_ dmgURL: URL, in workspace: URL) throws -> URL {
        let mountPoint = workspace.appendingPathComponent("mount", isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true, attributes: nil)

        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", "-nobrowse", "-readonly", "-mountpoint", mountPoint.path, dmgURL.path]
        try run(attach)

        defer {
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint.path]
            try? run(detach)
        }

        let foundApp = try findApp(in: mountPoint)
        let copiedApp = workspace.appendingPathComponent(foundApp.lastPathComponent, isDirectory: true)
        try FileManager.default.removeItemIfExists(at: copiedApp)

        let copy = Process()
        copy.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copy.arguments = [foundApp.path, copiedApp.path]
        try run(copy)
        return copiedApp
    }

    private func findApp(in directory: URL) throws -> URL {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        while let nextURL = enumerator?.nextObject() as? URL {
            if nextURL.pathExtension == "app", nextURL.lastPathComponent == "\(AppMetadata.projectName).app" {
                return nextURL
            }
        }
        throw AppUpdaterError.cannotPrepareInstalledApp
    }

    private func run(_ process: Process) throws {
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw AppUpdaterError.installScriptFailed(stderr)
        }
    }

    private func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}
