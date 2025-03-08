//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import OrderedCollections
import SwiftUI
import SwiftUIIntrospect

struct AppListView: View {
    enum Scope: Int, CaseIterable {
        case user
        case troll
        case system

        var localizedShortName: String {
            switch self {
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
            case .user:
                NSLocalizedString("User Applications", comment: "")
            case .troll:
                NSLocalizedString("TrollStore Applications", comment: "")
            case .system:
                NSLocalizedString("Injectable System Applications", comment: "")
            }
        }
    }

    @StateObject var searchViewModel = AppListSearchViewModel()
    @EnvironmentObject var appList: AppListModel

    @State var activeScope: Scope = .user
    @State var selectorOpenedURL: URLIdentifiable? = nil
    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?

    @AppStorage("isAdvertisementHidden")
    var isAdvertisementHidden: Bool = false

    var shouldShowAdvertisement: Bool {
        !isAdvertisementHidden &&
            !appList.isPaidProductInstalled &&
            !appList.filter.isSearching &&
            !appList.filter.showPatchedOnly
    }

    var appString: String {
        let appNameString = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrollFools"
        let appVersionString = String(
            format: "v%@ (%@)",
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        )

        let appStringFormat = """
        %@ %@ %@ © 2024-2025
        %@
        """

        return String(
            format: appStringFormat,
            appNameString, appVersionString,
            NSLocalizedString("Copyright", comment: ""),
            NSLocalizedString("Made with ♥ by OwnGoal Studio", comment: "")
        )
    }

    var body: some View {
        NavigationView {
            if #available(iOS 15, *) {
                searchableListView
                    .refreshable {
                        withAnimation {
                            appList.reload()
                        }
                    }
            } else {
                searchableListView
                    .introspect(.list, on: .iOS(.v14)) { tableView in
                        if tableView.refreshControl == nil {
                            tableView.refreshControl = {
                                let refreshControl = UIRefreshControl()
                                refreshControl.addAction(UIAction { action in
                                    appList.reload()
                                    if let control = action.sender as? UIRefreshControl {
                                        control.endRefreshing()
                                    }
                                }, for: .valueChanged)
                                return refreshControl
                            }()
                        }
                    }
            }
        }
        .sheet(item: $selectorOpenedURL) { urlWrapper in
            AppListView()
                .environmentObject(AppListModel(selectorURL: urlWrapper.url))
        }
        .onOpenURL { url in
            guard url.isFileURL, url.pathExtension.lowercased() == "dylib" else {
                return
            }
            selectorOpenedURL = URLIdentifiable(url: preprocessURL(url))
        }
        .onAppear {
            if Double.random(in: 0..<1) < 0.1 {
                isAdvertisementHidden = false
            }
        }
    }

    var searchableListView: some View {
        listView
            .onChange(of: appList.filter.showPatchedOnly) { showPatchedOnly in
                if let searchBar = searchViewModel.searchController?.searchBar {
                    reloadSearchBarPlaceholder(searchBar, showPatchedOnly: showPatchedOnly)
                }
            }
            .onReceive(searchViewModel.$searchKeyword) {
                appList.filter.searchKeyword = $0
            }
            .onReceive(searchViewModel.$searchScopeIndex) {
                activeScope = Scope(rawValue: $0) ?? .user
            }
            .introspect(.viewController, on: .iOS(.v14, .v15, .v16, .v17)) { viewController in
                if searchViewModel.searchController == nil {
                    viewController.navigationItem.hidesSearchBarWhenScrolling = true
                    viewController.navigationItem.searchController = {
                        let searchController = UISearchController(searchResultsController: nil)
                        searchController.searchResultsUpdater = searchViewModel
                        searchController.obscuresBackgroundDuringPresentation = false
                        searchController.hidesNavigationBarDuringPresentation = true
                        searchController.automaticallyShowsScopeBar = false
                        if #available(iOS 16, *) {
                            searchController.scopeBarActivation = .manual
                        }
                        setupSearchBar(searchController: searchController)
                        return searchController
                    }()
                    searchViewModel.searchController = viewController.navigationItem.searchController
                }
            }
    }

    var listView: some View {
        List {
            if AppListModel.hasTrollStore && appList.isRebuildNeeded {
                rebuildSection
            }

            switch activeScope {
            case .user:
                userAppGroup
            case .troll:
                trollAppGroup
            case .system:
                systemAppGroup
            }
        }
        .listStyle(.insetGrouped)
        .animation(.smooth, value: activeScope)
        .animation(.smooth, value: shouldShowAdvertisement)
        .animation(.smooth, value: combines(appList.isPaidProductInstalled, appList.unsupportedCount))
        .navigationTitle(appList.isSelectorMode ?
            NSLocalizedString("Select Application to Inject", comment: "") :
            NSLocalizedString("TrollFools", comment: "")
        )
        .navigationBarTitleDisplayMode(appList.isSelectorMode ? .inline : .automatic)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(
                    title: NSLocalizedString("Error", comment: ""),
                    error: lastError
                )
            } label: { }
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                    VStack {
                        Text(selectorURL.lastPathComponent).font(.headline)
                        Text(NSLocalizedString("Select Application to Inject", comment: "")).font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appList.filter.showPatchedOnly.toggle()
                } label: {
                    if #available(iOS 15, *) {
                        Image(systemName: appList.filter.showPatchedOnly
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    } else {
                        Image(systemName: appList.filter.showPatchedOnly
                            ? "eject.circle.fill"
                            : "eject.circle")
                    }
                }
                .accessibilityLabel(NSLocalizedString("Show Patched Only", comment: ""))
            }
        }
    }

    var userAppGroup: some View {
        Group {
            if !appList.filter.isSearching && !appList.filter.showPatchedOnly && appList.unsupportedCount > 0 {
                Section {
                } footer: {
                    paddedHeaderFooterText(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                }
                .transition(.opacity)
            }

            if #available(iOS 15, *) {
                if shouldShowAdvertisement {
                    advertisementSection
                        .transition(.opacity)
                }
            }

            appSections(appList.userApplications)
        }
        .transition(.opacity)
    }

    var trollAppGroup: some View {
        Group {
            appSections(appList.trollApplications)
        }
        .transition(.opacity)
    }

    var systemAppGroup: some View {
        Group {
            if !appList.filter.showPatchedOnly {
                Section {
                } footer: {
                    paddedHeaderFooterText(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                }
                .transition(.opacity)
            }

            appSections(appList.appleApplications)
        }
        .transition(.opacity)
    }

    func appSections(_ apps: OrderedDictionary<String, [App]>) -> some View {
        Group {
            if !apps.isEmpty {
                ForEach(Array(apps.keys), id: \.self) { sectionKey in
                    Section {
                        ForEach(apps[sectionKey] ?? [], id: \.id) { app in
                            NavigationLink {
                                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                                    InjectView(app, urlList: [selectorURL])
                                } else {
                                    OptionView(app)
                                }
                            } label: {
                                if #available(iOS 16, *) {
                                    AppListCell(app: app)
                                } else {
                                    AppListCell(app: app)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    } header: {
                        paddedHeaderFooterText(sectionKey)
                    } footer: {
                        if sectionKey == apps.keys.last {
                            footer
                        }
                    }
                }
            } else {
                Section {
                } header: {
                    paddedHeaderFooterText(NSLocalizedString("No Applications", comment: ""))
                        .textCase(.none)
                } footer: {
                    footer
                }
            }
        }
    }

    var rebuildSection: some View {
        Section {
            Button {
                rebuildIconCache()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Rebuild Icon Cache", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(NSLocalizedString("You need to rebuild the icon cache in TrollStore to apply changes.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if appList.isRebuilding {
                        if #available(iOS 16, *) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .controlSize(.large)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(2.0)
                        }
                    } else {
                        Image(systemName: "timelapse")
                            .font(.title)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.vertical, 4)
            }
            .disabled(appList.isRebuilding)
        }
    }

    @available(iOS 15.0, *)
    var advertisementSection: some View {
        Section {
            Button {
                UIApplication.shared.open(App.advertisementApp.url)
            } label: {
                if #available(iOS 16, *) {
                    AppListCell(app: App.advertisementApp)
                } else {
                    AppListCell(app: App.advertisementApp)
                        .padding(.vertical, 4)
                }
            }
            .foregroundColor(.primary)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    isAdvertisementHidden = true
                } label: {
                    Label(NSLocalizedString("Hide", comment: ""), systemImage: "eye.slash")
                }
                .tint(.red)
            }
        } header: {
            paddedHeaderFooterText(NSLocalizedString("Advertisement", comment: ""))
        }
    }

    var footer: some View {
        Group {
            if !appList.isSelectorMode && !appList.filter.isSearching {
                if #available(iOS 16, *) {
                    footerContent
                        .padding(.top, 8)
                } else if #available(iOS 15, *) {
                    footerContent
                        .padding(.top, 2)
                } else {
                    footerContent
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 16)
    }

    var footerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            Button {
                UIApplication.shared.open(URL(string: "https://github.com/Lessica/TrollFools")!)
            } label: {
                Text(NSLocalizedString("Source Code", comment: ""))
                    .font(.footnote)
            }
        }
    }

    private func rebuildIconCache() {
        withAnimation {
            appList.isRebuilding = true
        }

        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuilding = false
                    }
                }
            }

            do {
                try appList.rebuildIconCache()

                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuildNeeded = false
                    }
                }
            } catch {
                DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                DispatchQueue.main.async {
                    lastError = error
                    isErrorOccurred = true
                }
            }
        }
    }

    private func preprocessURL(_ url: URL) -> URL {
        let isInbox = url.path.contains("/Documents/Inbox/")
        guard isInbox else {
            return url
        }
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileNameComps = fileNameNoExt.components(separatedBy: CharacterSet(charactersIn: "._- "))
        guard let lastComp = fileNameComps.last, fileNameComps.count > 1, lastComp.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return url
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(String(fileNameNoExt.prefix(fileNameNoExt.count - lastComp.count - 1)))
            .appendingPathExtension(url.pathExtension)
        do {
            try? FileManager.default.removeItem(at: newURL)
            try FileManager.default.copyItem(at: url, to: newURL)
            return newURL
        } catch {
            return url
        }
    }

    private func setupSearchBar(searchController: UISearchController) {
        if let searchBarDelegate = searchController.searchBar.delegate, (searchBarDelegate as? NSObject) != searchViewModel {
            searchViewModel.forwardSearchBarDelegate = searchBarDelegate
        }

        searchController.searchBar.delegate = searchViewModel
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = Scope.allCases.map { $0.localizedShortName }
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no

        reloadSearchBarPlaceholder(searchController.searchBar, showPatchedOnly: appList.filter.showPatchedOnly)
    }

    private func reloadSearchBarPlaceholder(_ searchBar: UISearchBar, showPatchedOnly: Bool) {
        searchBar.placeholder = (showPatchedOnly
            ? NSLocalizedString("Search Patched…", comment: "")
            : NSLocalizedString("Search…", comment: ""))
    }

    @ViewBuilder
    private func paddedHeaderFooterText(_ content: String) -> some View {
        if #available(iOS 15, *) {
            Text(content)
                .font(.footnote)
        } else {
            Text(content)
                .font(.footnote)
                .padding(.horizontal, 16)
        }
    }
}

struct URLIdentifiable: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
