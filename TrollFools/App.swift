//
//  App.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import Foundation

final class App: Identifiable, ObservableObject {
    let id: String
    let name: String
    let latinName: String
    let type: String
    let teamID: String
    let url: URL
    let version: String?
    let isAdvertisement: Bool

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
    private var cancellables: Set<AnyCancellable> = []
    private static let reloadSubject = PassthroughSubject<String, Never>()

    init(
        id: String,
        name: String,
        type: String,
        teamID: String,
        url: URL,
        version: String? = nil,
        alternateIcon: UIImage? = nil,
        isAdvertisement: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.teamID = teamID
        self.url = url
        self.version = version
        self.isDetached = InjectorV3.main.isMetadataDetachedInBundle(url)
        self.isAllowedToAttachOrDetach = type == "User" && InjectorV3.main.isAllowedToAttachOrDetachMetadataInBundle(url)
        self.isInjected = InjectorV3.main.checkIsInjectedAppBundle(url)
        self.alternateIcon = alternateIcon
        self.isAdvertisement = isAdvertisement
        self.latinName = name
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)?
            .components(separatedBy: .whitespaces)
            .joined() ?? ""
        Self.reloadSubject
            .filter { $0 == id }
            .sink { [weak self] _ in
                self?._reload()
            }
            .store(in: &cancellables)
    }

    func reload() {
        Self.reloadSubject.send(id)
    }

    private func _reload() {
        reloadDetachedStatus()
        reloadInjectedStatus()
    }

    private func reloadDetachedStatus() {
        self.isDetached = InjectorV3.main.isMetadataDetachedInBundle(url)
        self.isAllowedToAttachOrDetach = isUser && InjectorV3.main.isAllowedToAttachOrDetachMetadataInBundle(url)
    }

    private func reloadInjectedStatus() {
        self.isInjected = InjectorV3.main.checkIsInjectedAppBundle(url)
    }
}

extension App {
    static let advertisementApp: App = {
        [
            App(
                id: NSLocalizedString("Record your phone calls like never before.", comment: ""),
                name: NSLocalizedString("TrollRecorder", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/trollrecorder")!,
                alternateIcon: .init(named: "tricon-default"),
                isAdvertisement: true
            ),
            App(
                id: NSLocalizedString("Bringing back the most advanced system and security analysis tool.", comment: ""),
                name: NSLocalizedString("Reveil", comment: ""),
                type: "System",
                teamID: "GXZ23M5TP2",
                url: URL(string: "https://havoc.app/package/reveil")!,
                alternateIcon: .init(named: "reveil-default"),
                isAdvertisement: true
            ),
        ].randomElement()!
    }()
}
