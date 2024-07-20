//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

class App: Identifiable, ObservableObject {
    let id: String
    let name: String
    let teamID: String
    let url: URL
    let version: String?

    @Published var isInjected: Bool = false

    lazy var icon: UIImage? = UIImage._applicationIconImage(forBundleIdentifier: id, format: 0, scale: 3.0)

    init(id: String, name: String, teamID: String, url: URL, version: String?) {
        self.id = id
        self.name = name
        self.teamID = teamID
        self.url = url
        self.version = version
        self.isInjected = Injector.isInjectedBundle(url)
    }

    func reloadInjectedStatus() {
        isInjected = Injector.isInjectedBundle(url)
    }
}

class AppListModel: ObservableObject {
    static let shared = AppListModel()

    @Published var userApps: [App]

    private init() {
        userApps = Self.getUserApps()
    }

    func refresh() {
        userApps = Self.getUserApps()
    }

    private static func getUserApps() -> [App] {
        LSApplicationWorkspace.default()
            .allApplications()
            .filter { $0.applicationType() == "User" && !$0.applicationIdentifier().hasPrefix("com.apple.") }
            .compactMap {
                guard let id = $0.applicationIdentifier(),
                      !id.hasPrefix("wiki.qaq."),
                      !id.hasPrefix("com.82flex."),
                      !id.hasPrefix("com.opa334."),
                      !id.hasPrefix("com.Alfie."),
                      !id.hasPrefix("org.coolstar."),
                      !id.hasPrefix("com.tigisoftware."),
                      !id.hasPrefix("com.icraze."),
                      !id.hasPrefix("ch.xxtou."),
                      let url = $0.bundleURL(),
                      let teamID = $0.teamID(),
                      let localizedName = $0.localizedName(),
                      let shortVersionString = $0.shortVersionString()
                else {
                    return nil
                }
                return App(
                    id: id,
                    name: localizedName,
                    teamID: teamID,
                    url: url,
                    version: shortVersionString
                )
            }
            .filter { Injector.isEligibleBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

class SearchOptions: ObservableObject {
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
            Image(uiImage: app.icon ?? UIImage())
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    if #available(iOS 15.0, *) {
                        Text(highlightedName)
                            .font(.headline)
                    } else {
                        Text(app.name)
                            .font(.headline)
                    }

                    if app.isInjected {
                        Image(systemName: "bandage")
                            .font(.subheadline)
                            .foregroundColor(.orange)
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
            (isSearching ? searchResults : vm.userApps)
                .filter { $0.isInjected }
        } else {
            isSearching ? searchResults : vm.userApps
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
                ForEach(filteredApps, id: \.id) { app in
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
            } header: {
                Text(showPatchedOnly ? NSLocalizedString("Injected Applications", comment: "") : NSLocalizedString("Injectable Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if #available(iOS 16.0, *) {
                    appListFooter
                        .padding(.top, 8)
                } else {
                    appListFooter
                        .padding(.top, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Applications", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        showPatchedOnly.toggle()
                    }
                } label: {
                    Image(systemName: showPatchedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
                        prompt: NSLocalizedString("Search…", comment: "")
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

    private func fetchSearchResults(for query: String) {
        searchResults = vm.userApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.id.localizedCaseInsensitiveContains(query)
        }
    }
}
