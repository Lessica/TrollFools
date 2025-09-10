//
//  Constants.swift
//  TrollFools
//
//  Created by 82Flex on 3/8/25.
//

import Foundation

enum Constants {
    private static let gInfoPlist: [AnyHashable: Any] = {
        var values = [
            "FeedbackMailTo": "mailto:82flex@gmail.com",
            "InviteLinkDiscord": "https://discord.gg/P2Hn82zS",
            "GitHubReleasePage": "https://github.com/Lessica/TrollFools/releases",
            "GitHubReleaseEndpointForUpgradeCheck": "https://api.github.com/repos/Lessica/TrollFools/releases",
        ]
        return values
    }()

    private static func infoValue<T>(forKey key: String) -> T {
        guard let value = gInfoPlist[key] as? T
        else { fatalError("Malformed application manifest") }
        return value
    }

    static let gFeedbackMailToURL: URL = .init(string: infoValue(forKey: "FeedbackMailTo"))!
    static let gInviteLinkDiscordURL: URL = .init(string: infoValue(forKey: "InviteLinkDiscord"))!

    static let gReleaseNotesURL: URL = .init(string: infoValue(forKey: "GitHubReleasePage"))!
    static let gUpdateCheckEndpoint: URL = .init(string: infoValue(forKey: "GitHubReleaseEndpointForUpgradeCheck"))!

    static let gAppName = (Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String) ?? "TrollFools"
    static let gAppVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    static let gAppBuildVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    static let gAppIdentifier = Bundle.main.bundleIdentifier ?? "wiki.qaq.TrollFools"
    static let gErrorDomain = "\(gAppIdentifier).error"

    static let updateManagerCheckInterval: TimeInterval = 7200 // 2 hours
    static let updateManagerRetryInterval: TimeInterval = 90 // 90 seconds
    static let updateManagerAlertDelayDuration: TimeInterval = 60 * 60 * 24 * 7 // 1 week
    static let trollStoreIdentifier = "com.opa334.TrollStore"
    static let trollStoreInstallURLScheme = "apple-magnifier://install?url="
}
