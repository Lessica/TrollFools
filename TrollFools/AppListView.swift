//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import SwiftUI
import SwiftUIIntrospect

struct AppListView: View {

    @StateObject var searchViewModel = AppListSearchViewModel()
    @EnvironmentObject var appList: AppListModel

    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?

    @State var selectorOpenedURL: URL? = nil

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
%@ %@ %@ © 2024-2025
%@
""", appNameString, appVersionString, NSLocalizedString("Copyright", comment: ""), NSLocalizedString("Made with ♥ by OwnGoal Studio", comment: ""))
    }

    let repoURL = URL(string: "https://github.com/Lessica/TrollFools")!

    func filteredAppList(_ apps: [App]) -> some View {
        ForEach(apps, id: \.id) { app in
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
    }

    var advertisementButton: some View {
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
    }

    var appListFooterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            Button {
                UIApplication.shared.open(repoURL)
            } label: {
                Text(NSLocalizedString("Source Code", comment: ""))
                    .font(.footnote)
            }
        }
    }

    var appListFooter: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !appList.filter.showPatchedOnly {
                Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                    .font(.footnote)
            }

            if !appList.isSelectorMode {
                if #available(iOS 16, *) {
                    appListFooterView
                        .padding(.top, 8)
                } else {
                    appListFooterView
                        .padding(.top, 2)
                }
            }
        }
    }

    var appListView: some View {
        List {
            if AppListModel.hasTrollStore && appList.isRebuildNeeded {
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
                                    // Fallback on earlier versions
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

            Section {
                filteredAppList(appList.userApplications)
            } header: {
                if #available(iOS 15, *) {
                    Text(NSLocalizedString("User Applications", comment: ""))
                        .font(.footnote)
                } else {
                    Text(NSLocalizedString("User Applications", comment: ""))
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }
            } footer: {
                if !appList.filter.isSearching && !appList.filter.showPatchedOnly && appList.unsupportedCount > 0 {
                    if #available(iOS 15, *) {
                        Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                            .font(.footnote)
                    } else {
                        Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                            .font(.footnote)
                            .padding(.horizontal, 16)
                    }
                }
            }

            Section {
                if #available(iOS 15, *) {
                    if !appList.isPaidProductInstalled {
                        advertisementButton
                    }
                }

                filteredAppList(appList.trollApplications)
            } header: {
                if #available(iOS 15, *) {
                    Text(NSLocalizedString("TrollStore Applications", comment: ""))
                        .font(.footnote)
                } else {
                    Text(NSLocalizedString("TrollStore Applications", comment: ""))
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }
            }

            Section {
                filteredAppList(appList.appleApplications)
            } header: {
                if #available(iOS 15, *) {
                    Text(NSLocalizedString("Injectable System Applications", comment: ""))
                        .font(.footnote)
                } else {
                    Text(NSLocalizedString("Injectable System Applications", comment: ""))
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }
            } footer: {
                if !appList.filter.isSearching {
                    if #available(iOS 15, *) {
                        appListFooter
                    } else {
                        appListFooter
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(appList.isSelectorMode ? NSLocalizedString("Select Application to Inject", comment: "") : NSLocalizedString("TrollFools", comment: ""))
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

    var body: some View {
        NavigationView {
            if #available(iOS 15, *) {
                appListView
                    .refreshable {
                        withAnimation {
                            appList.reload()
                        }
                    }
                    .searchable(
                        text: $appList.filter.searchKeyword,
                        placement: .automatic,
                        prompt: (appList.filter.showPatchedOnly
                                 ? NSLocalizedString("Search Patched…", comment: "")
                                 : NSLocalizedString("Search…", comment: ""))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } else {
                // Fallback on earlier versions
                appListView
                    .onChange(of: appList.filter.showPatchedOnly) { showPatchedOnly in
                        if let searchBar = searchViewModel.searchController?.searchBar {
                            searchBar.placeholder = (showPatchedOnly
                                                     ? NSLocalizedString("Search Patched…", comment: "")
                                                     : NSLocalizedString("Search…", comment: ""))
                        }
                    }
                    .onReceive(searchViewModel.$searchKeyword) {
                        appList.filter.searchKeyword = $0
                    }
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
                    .introspect(.viewController, on: .iOS(.v14)) { viewController in
                        if searchViewModel.searchController == nil {
                            viewController.navigationItem.hidesSearchBarWhenScrolling = true
                            viewController.navigationItem.searchController = {
                                let searchController = UISearchController(searchResultsController: nil)
                                searchController.searchResultsUpdater = searchViewModel
                                searchController.obscuresBackgroundDuringPresentation = false
                                searchController.hidesNavigationBarDuringPresentation = true
                                searchController.searchBar.placeholder = NSLocalizedString("Search…", comment: "")
                                return searchController
                            }()
                            searchViewModel.searchController = viewController.navigationItem.searchController
                        }
                    }
            }
        }
        .sheet(item: $selectorOpenedURL) { url in
            AppListView()
                .environmentObject(AppListModel(selectorURL: url))
        }
        .onOpenURL { url in
            guard url.isFileURL, url.pathExtension.lowercased() == "dylib" else {
                return
            }
            selectorOpenedURL = preprocessURL(url)
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
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

final class AppListSearchViewModel: NSObject, UISearchResultsUpdating, ObservableObject {
    @Published var searchKeyword: String = ""

    weak var searchController: UISearchController?

    func updateSearchResults(for searchController: UISearchController) {
        searchKeyword = searchController.searchBar.text ?? ""
    }
}
