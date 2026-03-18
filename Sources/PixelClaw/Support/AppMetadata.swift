import Foundation

enum AppMetadata {
    static let projectName = "PixelClaw"
    static let sourceCodeURL = URL(string: "https://github.com/masasron/PixelClaw")!
    static let creatorURL = URL(string: "https://x.com/RonMasas")!
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/masasron/PixelClaw/releases/latest")!

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var installedBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var displayVersion: String {
        guard let build = installedBuild, build != installedVersion else {
            return installedVersion
        }
        return "\(installedVersion) (\(build))"
    }
}
