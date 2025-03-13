//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import OrderedCollections
import SwiftUI

final class AppListModel: ObservableObject {
    enum Scope: Int, CaseIterable {
        case all
        case user
        case troll
        case system

        var localizedShortName: String {
            switch self {
            case .all:
                NSLocalizedString("All", comment: "")
            case .user:
                NSLocalizedString("User", comment: "")
            case .troll:
                NSLocalizedString("TrollStore", comment: "")
            case .system:
                NSLocalizedString("System", comment: "")
            }
        }

        var localizedName: String {
            switch self {
            case .all:
                NSLocalizedString("All Applications", comment: "")
            case .user:
                NSLocalizedString("User Applications", comment: "")
            case .troll:
                NSLocalizedString("TrollStore Applications", comment: "")
            case .system:
                NSLocalizedString("Injectable System Applications", comment: "")
            }
        }
    }

    static let hasTrollStore: Bool = { LSApplicationProxy(forIdentifier: "com.opa334.TrollStore") != nil }()
    private var _allApplications: [App] = []

    let selectorURL: URL?
    var isSelectorMode: Bool { selectorURL != nil }

    @Published var filter = FilterOptions()
    @Published var activeScope: Scope = .all
    @Published var activeScopeApps: OrderedDictionary<String, [App]> = [:]

    @Published var isPaidProductInstalled: Bool = false
    @Published var unsupportedCount: Int = 0

    @Published var isFilzaInstalled: Bool = false
    private let filzaURL = URL(string: "filza://")

    @Published var isRebuildNeeded: Bool = false

    private let applicationChanged = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(selectorURL: URL? = nil) {
        self.selectorURL = selectorURL
        reload()

        Publishers.CombineLatest(
            $filter,
            $activeScope
        )
        .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
        .sink { [weak self] _ in
            self?.performFilter()
        }
        .store(in: &cancellables)

        applicationChanged
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(darwinCenter, Unmanaged.passRetained(self).toOpaque(), { _, observer, _, _, _ in
            guard let observer = Unmanaged<AppListModel>.fromOpaque(observer!).takeUnretainedValue() as AppListModel? else {
                return
            }
            observer.applicationChanged.send()
        }, "com.apple.LaunchServices.ApplicationsChanged" as CFString, nil, .coalesce)
    }

    deinit {
        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(darwinCenter, Unmanaged.passUnretained(self).toOpaque(), nil, nil)
    }

    func reload() {
        let allApplications = Self.fetchApplications(&isPaidProductInstalled, &unsupportedCount)
        allApplications.forEach { $0.appList = self }
        _allApplications = allApplications
        if let filzaURL {
            isFilzaInstalled = UIApplication.shared.canOpenURL(filzaURL)
        } else {
            isFilzaInstalled = false
        }
        performFilter()
    }

    func performFilter() {
        var filteredApplications = _allApplications

        if !filter.searchKeyword.isEmpty {
            filteredApplications = filteredApplications.filter {
                $0.name.localizedCaseInsensitiveContains(filter.searchKeyword) || $0.id.localizedCaseInsensitiveContains(filter.searchKeyword) ||
                    (
                        $0.latinName.localizedCaseInsensitiveContains(
                            filter.searchKeyword
                                .components(separatedBy: .whitespaces).joined()
                        )
                    )
            }
        }

        if filter.showPatchedOnly {
            filteredApplications = filteredApplications.filter { $0.isInjected }
        }

        switch activeScope {
        case .all:
            activeScopeApps = Self.groupedAppList(filteredApplications)
        case .user:
            activeScopeApps = Self.groupedAppList(filteredApplications.filter { $0.isUser })
        case .troll:
            activeScopeApps = Self.groupedAppList(filteredApplications.filter { $0.isFromTroll })
        case .system:
            activeScopeApps = Self.groupedAppList(filteredApplications.filter { $0.isFromApple })
        }
    }

    private static let excludedIdentifiers: Set<String> = [
        "com.opa334.Dopamine",
        "org.coolstar.SileoStore",
        "xyz.willy.Zebra",
    ]

    private static func fetchApplications(_ isPaidProductInstalled: inout Bool, _ unsupportedCount: inout Int) -> [App] {
        let allApps: [App] = LSApplicationWorkspace.default()
            .allApplications()
            .compactMap { proxy in
                guard let id = proxy.applicationIdentifier(),
                      let url = proxy.bundleURL(),
                      let teamID = proxy.teamID(),
                      let appType = proxy.applicationType(),
                      let localizedName = proxy.localizedName()
                else {
                    return nil
                }

                if id == "wiki.qaq.trapp" || id == "com.82flex.reveil" {
                    isPaidProductInstalled = true
                }

                guard !id.hasPrefix("wiki.qaq.") && !id.hasPrefix("com.82flex.") else {
                    return nil
                }

                guard !excludedIdentifiers.contains(id) else {
                    return nil
                }

                let shortVersionString: String? = proxy.shortVersionString()
                let app = App(
                    id: id,
                    name: localizedName,
                    type: appType,
                    teamID: teamID,
                    url: url,
                    version: shortVersionString
                )

                if app.isUser && app.isFromApple {
                    return nil
                }

                guard app.isRemovable else {
                    return nil
                }

                return app
            }

        let filteredApps = allApps
            .filter { $0.isSystem || InjectorV3.main.checkIsEligibleAppBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count

        return filteredApps
    }
}

extension AppListModel {
    func openInFilza(_ url: URL) {
        guard let filzaURL else {
            return
        }
        let fileURL = filzaURL.appendingPathComponent(url.path)
        UIApplication.shared.open(fileURL)
    }

    func rebuildIconCache() {
        // Sadly, we can't call `trollstorehelper` directly because only TrollStore can launch it without error.
        DispatchQueue.global(qos: .userInitiated).async {
            LSApplicationWorkspace.default().openApplication(withBundleID: "com.opa334.TrollStore")
        }
    }
}

extension AppListModel {
    static let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#"
    private static let allowedCharacterSet = CharacterSet(charactersIn: allowedCharacters)

    private static func groupedAppList(_ apps: [App]) -> OrderedDictionary<String, [App]> {
        var groupedApps = OrderedDictionary<String, [App]>()

        for app in apps {
            var key = app.name
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .applyingTransform(.stripCombiningMarks, reverse: false)?
                .applyingTransform(.toLatin, reverse: false)?
                .applyingTransform(.stripDiacritics, reverse: false)?
                .prefix(1).uppercased() ?? "#"

            if let scalar = UnicodeScalar(key) {
                if !allowedCharacterSet.contains(scalar) {
                    key = "#"
                }
            } else {
                key = "#"
            }

            if groupedApps[key] == nil {
                groupedApps[key] = []
            }

            groupedApps[key]?.append(app)
        }

        groupedApps.sort { app1, app2 in
            if let c1 = app1.key.first,
               let c2 = app2.key.first,
               let idx1 = allowedCharacters.firstIndex(of: c1),
               let idx2 = allowedCharacters.firstIndex(of: c2)
            {
                return idx1 < idx2
            }
            return app1.key < app2.key
        }

        return groupedApps
    }
}
