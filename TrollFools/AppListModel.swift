//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import SwiftUI

final class AppListModel: ObservableObject {
    static let hasTrollStore: Bool = { LSApplicationProxy(forIdentifier: "com.opa334.TrollStore") != nil }()
    private var _allApplications: [App] = []

    let selectorURL: URL?
    var isSelectorMode: Bool { selectorURL != nil }

    @Published var filter = FilterOptions()
    @Published var userApplications: [App] = []
    @Published var trollApplications: [App] = []
    @Published var appleApplications: [App] = []

    @Published var hasTrollRecorder: Bool = false
    @Published var unsupportedCount: Int = 0

    @Published var isFilzaInstalled: Bool = false
    private let filzaURL = URL(string: "filza://")

    @Published var isRebuildNeeded: Bool = false
    @Published var isRebuilding: Bool = false

    private let applicationChanged = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(selectorURL: URL? = nil) {
        self.selectorURL = selectorURL
        reload()

        $filter
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                withAnimation {
                    self?.performFilter()
                }
            }
            .store(in: &cancellables)

        applicationChanged
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                withAnimation {
                    self?.reload()
                }
            }
            .store(in: &cancellables)

        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(darwinCenter, Unmanaged.passRetained(self).toOpaque(), { center, observer, name, object, userInfo in
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
        let allApplications = Self.fetchApplications(&hasTrollRecorder, &unsupportedCount)
        allApplications.forEach { $0.appList = self }
        self._allApplications = allApplications
        if let filzaURL {
            self.isFilzaInstalled = UIApplication.shared.canOpenURL(filzaURL)
        } else {
            self.isFilzaInstalled = false
        }
        performFilter()
    }

    func performFilter() {
        var filteredApplications = _allApplications

        if !filter.searchKeyword.isEmpty {
            filteredApplications = filteredApplications.filter {
                $0.name.localizedCaseInsensitiveContains(filter.searchKeyword) || $0.id.localizedCaseInsensitiveContains(filter.searchKeyword)
            }
        }

        if filter.showPatchedOnly {
            filteredApplications = filteredApplications.filter { $0.isInjected }
        }

        userApplications = filteredApplications.filter { $0.isUser }
        trollApplications = filteredApplications.filter { $0.isFromTroll }
        appleApplications = filteredApplications.filter { $0.isFromApple }
    }

    private static let excludedIdentifiers: Set<String> = [
        "com.opa334.Dopamine",
        "org.coolstar.SileoStore",
    ]

    private static func fetchApplications(_ hasTrollRecorder: inout Bool, _ unsupportedCount: inout Int) -> [App] {
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

                if id == "wiki.qaq.trapp" {
                    hasTrollRecorder = true
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
            .filter { $0.isSystem || Injector.isBundleEligible($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count

        return filteredApps
    }

    func openInFilza(_ url: URL) {
        guard let filzaURL else {
            return
        }
        let fileURL = filzaURL.appendingPathComponent(url.path)
        UIApplication.shared.open(fileURL)
    }

    func rebuildIconCache() throws {
        // Sadly, we can't call `trollstorehelper` directly because only TrollStore can launch it without error.
        LSApplicationWorkspace.default().openApplication(withBundleID: "com.opa334.TrollStore")
    }
}
