//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

final class App: Identifiable, ObservableObject {
    let id: String
    let name: String
    let type: String
    let teamID: String
    let url: URL
    let version: String?

    @Published var isInjected: Bool = false

    lazy var icon: UIImage? = UIImage._applicationIconImage(forBundleIdentifier: id, format: 0, scale: 3.0)
    var alternateIcon: UIImage?

    lazy var isUser: Bool = type == "User"
    lazy var isSystem: Bool = !isUser
    lazy var isFromApple: Bool = id.hasPrefix("com.apple.")
    lazy var isFromTroll: Bool = isSystem && !isFromApple
    lazy var isRemovable: Bool = url.path.contains("/var/containers/Bundle/Application/")

    init(id: String,
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
        self.isInjected = Injector.isInjectedBundle(url)
        self.alternateIcon = alternateIcon
    }

    func reloadInjectedStatus() {
        self.isInjected = Injector.isInjectedBundle(url)
    }
}

final class AppListModel: ObservableObject {
    static let shared = AppListModel()

    @Published var allApplications: [App] = []
    @Published var hasTrollRecorder: Bool = false
    @Published var unsupportedCount: Int = 0

    private init() {
        refresh()
    }

    func refresh() {
        self.allApplications = Self.fetchApplications(&hasTrollRecorder, &unsupportedCount)
    }

    private static let excludedIdentifiers: Set<String> = [
        "com.opa334.Dopamine",
        "org.coolstar.SileoStore",
    ]

    private static func fetchApplications(_ hasTrollRecorder: inout Bool, _ unsupportedCount: inout Int) -> [App] {
        let allApps: [App] = LSApplicationWorkspace.default()
            .allApplications()
            .compactMap {
                guard let id = $0.applicationIdentifier(),
                      let url = $0.bundleURL(),
                      let teamID = $0.teamID(),
                      let appType = $0.applicationType(),
                      let localizedName = $0.localizedName(),
                      let shortVersionString = $0.shortVersionString()
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
            .filter { $0.isSystem || Injector.isEligibleBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count

        return filteredApps
    }
}

final class SearchOptions: ObservableObject {
    @Published var keyword = ""

    func reset() {
        keyword = ""
    }
}

struct AppListCell: View {
    @StateObject var app: App
    @EnvironmentObject var searchOptions: SearchOptions

    @available(iOS 15.0, *)
    var highlightedName: AttributedString {
        let name = app.name
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: searchOptions.keyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @available(iOS 15.0, *)
    var highlightedId: AttributedString {
        let id = app.id
        var attributedString = AttributedString(id)
        if let range = attributedString.range(of: searchOptions.keyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if #available(iOS 15.0, *) {
                        Text(highlightedName)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text(app.name)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    if app.isInjected {
                        Image(systemName: "bandage")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .accessibilityLabel(NSLocalizedString("Patched", comment: ""))
                    }
                }

                if #available(iOS 15.0, *) {
                    Text(highlightedId)
                        .font(.subheadline)
                } else {
                    Text(app.id)
                        .font(.subheadline)
                }
            }

            Spacer()

            if let version = app.version {
                Text(version)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AppListView: View {
    @StateObject var vm = AppListModel.shared

    @State var showPatchedOnly = false
    @State var searchResults: [App] = []

    @StateObject var searchOptions = SearchOptions()

    var appNameString: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrollFools"
    }

    var appVersionString: String {
        String(format: "v%@ (%@)",
               Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
               Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")
    }

    var appString: String {
        String(format: """
%@ %@ %@ © 2024
%@
""", appNameString, appVersionString, NSLocalizedString("Copyright", comment: ""), NSLocalizedString("Lessica, Lakr233, mlgm and other contributors.", comment: ""))
    }

    let repoURL = URL(string: "https://github.com/Lessica/TrollFools")

    var isSearching: Bool {
        return !searchOptions.keyword.isEmpty
    }

    var filteredApps: [App] {
        if showPatchedOnly {
            (isSearching ? searchResults : vm.allApplications)
                .filter { $0.isInjected }
        } else {
            isSearching ? searchResults : vm.allApplications
        }
    }

    var filteredUserApps: [App] {
        filteredApps.filter { $0.isUser }
    }

    var filteredSystemApps: [App] {
        filteredApps.filter { $0.isSystem }
    }

    var filteredTrollApps: [App] {
        filteredSystemApps.filter { !$0.id.hasPrefix("com.apple.") }
    }

    var filteredAppleApps: [App] {
        filteredSystemApps.filter { $0.id.hasPrefix("com.apple.") }
    }

    func filteredAppList(_ apps: [App]) -> some View {
        ForEach(apps, id: \.id) { app in
            NavigationLink {
                OptionView(app)
            } label: {
                if #available(iOS 16.0, *) {
                    AppListCell(app: app)
                        .environmentObject(searchOptions)
                } else {
                    AppListCell(app: app)
                        .environmentObject(searchOptions)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    var appListFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            Button {
                guard let url = repoURL else {
                    return
                }
                UIApplication.shared.open(url)
            } label: {
                Text(NSLocalizedString("Source Code", comment: ""))
                    .font(.footnote)
            }
        }
    }

    var appList: some View {
        List {
            Section {
                filteredAppList(filteredUserApps)
            } header: {
                Text(NSLocalizedString("User Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !isSearching && !showPatchedOnly && vm.unsupportedCount > 0 {
                    Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), vm.unsupportedCount))
                        .font(.footnote)
                }
            }

            Section {
                filteredAppList(filteredTrollApps)
            } header: {
                Text(NSLocalizedString("TrollStore Applications", comment: ""))
                    .font(.footnote)
            }

            Section {
                filteredAppList(filteredAppleApps)
            } header: {
                Text(NSLocalizedString("Injectable System Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !isSearching {
                    VStack(alignment: .leading, spacing: 20) {
                        if !showPatchedOnly {
                            Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                                .font(.footnote)
                        }

                        if #available(iOS 16.0, *) {
                            appListFooter
                                .padding(.top, 8)
                        } else {
                            appListFooter
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("TrollFools", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        showPatchedOnly.toggle()
                    }
                } label: {
                    if #available(iOS 15.0, *) {
                        Image(systemName: showPatchedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    } else {
                        Image(systemName: showPatchedOnly ? "eject.circle.fill" : "eject.circle")
                    }
                }
                .accessibilityLabel(NSLocalizedString("Show Patched Only", comment: ""))
            }
        }
    }

    var body: some View {
        NavigationView {
            if #available(iOS 15.0, *) {
                appList
                    .refreshable {
                        withAnimation {
                            vm.refresh()
                        }
                    }
                    .searchable(
                        text: $searchOptions.keyword,
                        placement: .automatic,
                        prompt: (showPatchedOnly
                                 ? NSLocalizedString("Search Patched…", comment: "")
                                 : NSLocalizedString("Search…", comment: ""))
                    )
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchOptions.keyword) { keyword in
                        fetchSearchResults(for: keyword)
                    }
            } else {
                // Fallback on earlier versions
                appList
            }
        }
    }

    func fetchSearchResults(for query: String) {
        searchResults = vm.allApplications.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.id.localizedCaseInsensitiveContains(query)
        }
    }
}
