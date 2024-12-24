//
//  App.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

final class App: Identifiable, ObservableObject {
    let id: String
    let name: String
    let type: String
    let teamID: String
    let url: URL
    let version: String?

    @Published var isDetached: Bool = false
    @Published var isAllowedToAttachOrDetach: Bool
    @Published var isInjected: Bool = false

    lazy var icon: UIImage? = UIImage._applicationIconImage(forBundleIdentifier: id, format: 0, scale: 3.0)
    var alternateIcon: UIImage?

    lazy var isUser: Bool = type == "User"
    lazy var isSystem: Bool = !isUser
    lazy var isFromApple: Bool = id.hasPrefix("com.apple.")
    lazy var isFromTroll: Bool = isSystem && !isFromApple
    lazy var isRemovable: Bool = url.path.contains("/var/containers/Bundle/Application/")

    weak var appList: AppListModel?

    init(
        id: String,
        name: String,
        type: String,
        teamID: String,
        url: URL,
        version: String? = nil,
        alternateIcon: UIImage? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.teamID = teamID
        self.url = url
        self.version = version
        self.isDetached = Injector.isBundleDetached(url)
        self.isAllowedToAttachOrDetach = type == "User" && Injector.isBundleAllowedToAttachOrDetach(url)
        self.isInjected = Injector.isBundleInjected(url)
        self.alternateIcon = alternateIcon
    }

    func reload() {
        reloadDetachedStatus()
        reloadInjectedStatus()
    }

    private func reloadDetachedStatus() {
        self.isDetached = Injector.isBundleDetached(url)
        self.isAllowedToAttachOrDetach = isUser && Injector.isBundleAllowedToAttachOrDetach(url)
    }

    private func reloadInjectedStatus() {
        self.isInjected = Injector.isBundleInjected(url)
    }
}
