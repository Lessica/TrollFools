//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import CocoaLumberjackSwift
import SwiftUI
import SwiftUIIntrospect
import ZIPFoundation

struct EjectListView: View {
    @StateObject var searchViewModel = AppListSearchModel()
    @StateObject var ejectList: EjectListModel

    @State var quickLookExport: URL?
    @State var isDeletingAll = false
    @State var isExportingAll = false
    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?

    @StateObject var viewControllerHost = ViewControllerHost()

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.id)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.id)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.id)")
    }

    var body: some View {
        refreshableListView
            .toolbar { toolbarContent }
            .animation(.easeOut, value: isExportingAll)
            .quickLookPreview($quickLookExport)
    }

    var refreshableListView: some View {
        Group {
            if #available(iOS 15, *) {
                searchableListView
                    .refreshable {
                        ejectList.reload()
                    }
            } else {
                searchableListView
                    .introspect(.list, on: .iOS(.v14)) { tableView in
                        if tableView.refreshControl == nil {
                            tableView.refreshControl = {
                                let refreshControl = UIRefreshControl()
                                refreshControl.addAction(UIAction { action in
                                    ejectList.reload()
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
    }

    var searchableListView: some View {
        Group {
            if #available(iOS 15, *) {
                ejectListView
                    .onViewWillAppear { viewController in
                        viewControllerHost.viewController = viewController
                    }
                    .searchable(
                        text: $ejectList.filter.searchKeyword,
                        placement: .automatic,
                        prompt: NSLocalizedString("Search…", comment: "")
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } else {
                // Fallback on earlier versions
                ejectListView
                    .onReceive(searchViewModel.$searchKeyword) {
                        ejectList.filter.searchKeyword = $0
                    }
                    .introspect(.viewController, on: .iOS(.v14)) { viewController in
                        viewControllerHost.viewController = viewController
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
    }

    var ejectListView: some View {
        List {
            Section {
                ForEach(ejectList.filteredPlugIns) {
                    deletablePlugInCell($0)
                }
                .onDelete(perform: deletePlugIns)
            } header: {
                paddedHeaderFooterText(ejectList.filteredPlugIns.isEmpty
                    ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                    : NSLocalizedString("Injected Plug-Ins", comment: ""))
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if ejectList.app.isFromTroll {
                        paddedHeaderFooterText(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: combines(
            ejectList.filter,
            isDeletingAll
        ))
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(
                    title: NSLocalizedString("Error", comment: ""),
                    error: lastError
                )
            } label: { }
        })
    }

    var deleteAllButton: some View {
        if #available(iOS 15, *) {
            Button(role: .destructive) {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        } else {
            Button {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        }
    }

    var deleteAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")

            Spacer()

            if isDeletingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .transition(.opacity)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 16.4, *) {
                ShareLink(
                    item: CompressedFileRepresentation(
                        name: "\(ejectList.app.name)_\(ejectList.app.id)_\(UUID().uuidString.components(separatedBy: "-").last ?? "").zip",
                        urls: ejectList.injectedPlugIns.map(\.url)
                    ),
                    preview: SharePreview(
                        String(format: NSLocalizedString("%ld Plug-Ins of “%@”", comment: ""), ejectList.injectedPlugIns.count, ejectList.app.name)
                    )
                ) {
                    if isExportingAll {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .transition(.opacity)
                    } else {
                        Label(NSLocalizedString("Export All", comment: ""), systemImage: "square.and.arrow.up")
                            .transition(.opacity)
                    }
                }
                .disabled(ejectList.injectedPlugIns.isEmpty)
            } else {
                Button {
                    exportAll()
                } label: {
                    if isExportingAll {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .transition(.opacity)
                    } else {
                        Label(NSLocalizedString("Export All", comment: ""), systemImage: "square.and.arrow.up")
                            .transition(.opacity)
                    }
                }
                .disabled(ejectList.injectedPlugIns.isEmpty)
            }
        }
    }

    private func deletablePlugInCell(_ plugin: InjectedPlugIn) -> some View {
        Group {
            if #available(iOS 16, *) {
                PlugInCell(plugin, quickLookExport: $quickLookExport)
                    .environmentObject(ejectList)
            } else {
                PlugInCell(plugin, quickLookExport: $quickLookExport)
                    .environmentObject(ejectList)
                    .padding(.vertical, 4)
            }
        }
    }

    private func deletePlugIns(at offsets: IndexSet) {
        var logFileURL: URL?

        do {
            let plugInsToRemove = offsets.map { ejectList.filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }

            let injector = try InjectorV3(ejectList.app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = ejectList.app.id
            }

            if injector.teamID.isEmpty {
                injector.teamID = ejectList.app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            try injector.eject(plugInURLsToRemove)

            ejectList.app.reload()
            ejectList.reload()
        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)

            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]

            if let logFileURL {
                userInfo[NSURLErrorKey] = logFileURL
            }

            let nsErr = NSError(domain: gTrollFoolsErrorDomain, code: 0, userInfo: userInfo)

            lastError = nsErr
            isErrorOccurred = true
        }
    }

    private func deleteAll() {
        var logFileURL: URL?

        do {
            let injector = try InjectorV3(ejectList.app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = ejectList.app.id
            }

            if injector.teamID.isEmpty {
                injector.teamID = ejectList.app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            let view = viewControllerHost.viewController?
                .navigationController?.view

            view?.isUserInteractionEnabled = false

            isDeletingAll = true

            DispatchQueue.global(qos: .userInteractive).async {
                defer {
                    DispatchQueue.main.async {
                        ejectList.app.reload()
                        ejectList.reload()

                        isDeletingAll = false
                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.ejectAll()
                } catch {
                    DispatchQueue.main.async {
                        DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                        var userInfo: [String: Any] = [
                            NSLocalizedDescriptionKey: error.localizedDescription,
                        ]

                        if let logFileURL {
                            userInfo[NSURLErrorKey] = logFileURL
                        }

                        let nsErr = NSError(domain: gTrollFoolsErrorDomain, code: 0, userInfo: userInfo)

                        lastError = nsErr
                        isErrorOccurred = true
                    }
                }
            }
        } catch {
            lastError = error
            isErrorOccurred = true
        }
    }

    private func exportAll() {
        let view = viewControllerHost.viewController?
            .navigationController?.view

        view?.isUserInteractionEnabled = false

        isExportingAll = true

        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    isExportingAll = false
                    view?.isUserInteractionEnabled = true
                }
            }

            do {
                try _exportAll()
            } catch {
                DispatchQueue.main.async {
                    DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                    lastError = error
                    isErrorOccurred = true
                }
            }
        }
    }

    private func _exportAll() throws {
        let exportURL = InjectorV3.temporaryRoot
            .appendingPathComponent("Exports_\(UUID().uuidString)", isDirectory: true)

        let fileMgr = FileManager.default
        try fileMgr.createDirectory(at: exportURL, withIntermediateDirectories: true)

        for plugin in ejectList.injectedPlugIns {
            let exportURL = exportURL.appendingPathComponent(plugin.url.lastPathComponent)
            try fileMgr.copyItem(at: plugin.url, to: exportURL)
        }

        let zipURL = InjectorV3.temporaryRoot
            .appendingPathComponent(
                "\(ejectList.app.name)_\(ejectList.app.id)_\(UUID().uuidString.components(separatedBy: "-").last ?? "").zip")

        try fileMgr.zipItem(at: exportURL, to: zipURL, shouldKeepParent: false)

        DispatchQueue.main.async {
            quickLookExport = zipURL
        }
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

@available(iOS 16.0, *)
private struct CompressedFileRepresentation: Transferable {
    let name: String
    let urls: [URL]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { archive in
            let exportURL = InjectorV3.temporaryRoot
                .appendingPathComponent("Exports_\(UUID().uuidString)", isDirectory: true)

            let fileMgr = FileManager.default
            try fileMgr.createDirectory(at: exportURL, withIntermediateDirectories: true)

            for url in archive.urls {
                let exportURL = exportURL.appendingPathComponent(url.lastPathComponent)
                try fileMgr.copyItem(at: url, to: exportURL)
            }

            let zipURL = InjectorV3.temporaryRoot
                .appendingPathComponent(archive.name)

            try fileMgr.zipItem(at: exportURL, to: zipURL, shouldKeepParent: false)

            return SentTransferredFile(zipURL)
        }
    }
}
