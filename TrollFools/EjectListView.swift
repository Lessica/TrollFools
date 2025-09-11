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
    @State var isEnablingAll = false
    @State var isDisablingAll = false
    @State var isDeletingAll = false
    @State var isExportingAll = false
    @State var isErrorOccurred = false
    @State var lastError: Error?

    @State var isWarningPresented = false

    @StateObject var viewControllerHost = ViewControllerHost()

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy

    var shouldShowActions: Bool {
        !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty
    }

    var shouldDisableActions: Bool {
        isEnablingAll || isDisablingAll || isDeletingAll
    }

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.bid)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.bid)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.bid)")
    }

    var body: some View {
        if #available(iOS 15, *) {
            content
                .alert(NSLocalizedString("Eject All", comment: ""), isPresented: $isWarningPresented) {
                    Button(role: .destructive) {
                        deleteAll(shouldDesist: true)
                    } label: {
                        Text(NSLocalizedString("Confirm", comment: ""))
                    }
                    Button(role: .cancel) {
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    Text(NSLocalizedString("Are you sure you want to eject all plug-ins? This action cannot be undone.", comment: ""))
                }
        } else {
            content
        }
    }

    var content: some View {
        refreshableListView
            .toolbar { toolbarContent }
            .animation(.easeOut, value: isExportingAll)
            .quickLookPreview($quickLookExport)
    }

    @ViewBuilder
    var refreshableListView: some View {
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

    @ViewBuilder
    var searchableListView: some View {
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
                    viewController.navigationItem.hidesSearchBarWhenScrolling = true
                    viewControllerHost.viewController = viewController
                    if searchViewModel.searchController == nil {
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
            } footer: {
                paddedHeaderFooterText(NSLocalizedString("After the app upgrade, any injected plugins will be disabled. You will need to manually re-enable them.", comment: ""))
            }

            Section {
                if shouldShowActions {
                    enableAllButton
                        .disabled(shouldDisableActions || !ejectList.isOkToEnableAll)
                        .foregroundColor(shouldDisableActions ? .secondary : .accentColor)

                    disableAllButton
                        .disabled(shouldDisableActions || !ejectList.isOkToDisableAll)
                        .foregroundColor(shouldDisableActions ? .secondary : .accentColor)
                }
            }

            Section {
                if shouldShowActions {
                    deleteAllButton
                        .disabled(shouldDisableActions)
                        .foregroundColor(shouldDisableActions ? .secondary : Color(.systemRed))
                }
            } footer: {
                if shouldShowActions && ejectList.app.isFromTroll {
                    paddedHeaderFooterText(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: combines(
            ejectList.filter,
            ejectList.isOkToEnableAll,
            ejectList.isOkToDisableAll,
            isEnablingAll,
            isDisablingAll,
            isDeletingAll
        ))
        .background(NavigationLink(isActive: $isErrorOccurred) {
            FailureView(
                title: NSLocalizedString("Error", comment: ""),
                error: lastError
            )
        } label: { })
        .onChange(of: ejectList.processingPlugIn) { plugIn in
            if let plugIn {
                togglePlugIn(plugIn)
            }
        }
    }

    var enableAllButton: some View {
        Button {
            enableAll()
        } label: {
            enableAllButtonLabel
        }
    }

    var enableAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Enable All", comment: ""), systemImage: "square.stack.3d.up")

            Spacer()

            if isEnablingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .transition(.opacity)
            }
        }
    }

    var disableAllButton: some View {
        Button {
            disableAll()
        } label: {
            disableAllButtonLabel
        }
    }

    var disableAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Disable All", comment: ""), systemImage: "square.stack.3d.up.slash")

            Spacer()

            if isDisablingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .transition(.opacity)
            }
        }
    }

    var deleteAllButton: some View {
        if #available(iOS 15, *) {
            Button(role: .destructive) {
                isWarningPresented = true
            } label: {
                deleteAllButtonLabel
            }
        } else {
            Button {
                deleteAll(shouldDesist: true)
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
                        name: "\(ejectList.app.name)_\(ejectList.app.bid)_\(UUID().uuidString.components(separatedBy: "-").last ?? "").zip",
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

    @ViewBuilder
    private func deletablePlugInCell(_ plugin: InjectedPlugIn) -> some View {
        if #available(iOS 16, *) {
            PlugInCell(plugin, quickLookExport: $quickLookExport)
                .environmentObject(ejectList)
        } else {
            PlugInCell(plugin, quickLookExport: $quickLookExport)
                .environmentObject(ejectList)
                .padding(.vertical, 4)
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
                injector.appID = ejectList.app.bid
            }

            if injector.teamID.isEmpty {
                injector.teamID = ejectList.app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            try injector.eject(plugInURLsToRemove, shouldDesist: true)

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

            let nsErr = NSError(domain: Constants.gErrorDomain, code: 0, userInfo: userInfo)

            lastError = nsErr
            isErrorOccurred = true
        }
    }

    private func togglePlugIn(_ plugIn: InjectedPlugIn) {
        var logFileURL: URL?

        do {
            let plugInURLsToProcess = [plugIn.url]

            let injector = try InjectorV3(ejectList.app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = ejectList.app.bid
            }

            if injector.teamID.isEmpty {
                injector.teamID = ejectList.app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            if plugIn.isEnabled {
                try injector.eject(plugInURLsToProcess, shouldDesist: false)
            } else {
                try injector.inject(plugInURLsToProcess, shouldPersist: false)
            }

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

            let nsErr = NSError(domain: Constants.gErrorDomain, code: 0, userInfo: userInfo)

            lastError = nsErr
            isErrorOccurred = true
        }
    }

    private func enableAll() {
        let disabledPlugInURLs = ejectList.injectedPlugIns
            .filter { !$0.isEnabled }
            .map { $0.url }

        var logFileURL: URL?

        do {
            let injector = try InjectorV3(ejectList.app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = ejectList.app.bid
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

            isEnablingAll = true
            isDisablingAll = false
            isDeletingAll = false

            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    DispatchQueue.main.async {
                        ejectList.app.reload()
                        ejectList.reload()

                        isEnablingAll = false
                        isDisablingAll = false
                        isDeletingAll = false

                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.inject(disabledPlugInURLs, shouldPersist: false)
                } catch {
                    DispatchQueue.main.async {
                        DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                        var userInfo: [String: Any] = [
                            NSLocalizedDescriptionKey: error.localizedDescription,
                        ]

                        if let logFileURL {
                            userInfo[NSURLErrorKey] = logFileURL
                        }

                        let nsErr = NSError(domain: Constants.gErrorDomain, code: 0, userInfo: userInfo)

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

    private func disableAll() {
        deleteAll(shouldDesist: false)
    }

    private func deleteAll(shouldDesist: Bool) {
        var logFileURL: URL?

        do {
            let injector = try InjectorV3(ejectList.app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = ejectList.app.bid
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

            isEnablingAll = false
            isDisablingAll = !shouldDesist
            isDeletingAll = shouldDesist

            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    DispatchQueue.main.async {
                        ejectList.app.reload()
                        ejectList.reload()

                        isEnablingAll = false
                        isDisablingAll = false
                        isDeletingAll = false

                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.ejectAll(shouldDesist: shouldDesist)
                } catch {
                    DispatchQueue.main.async {
                        DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                        var userInfo: [String: Any] = [
                            NSLocalizedDescriptionKey: error.localizedDescription,
                        ]

                        if let logFileURL {
                            userInfo[NSURLErrorKey] = logFileURL
                        }

                        let nsErr = NSError(domain: Constants.gErrorDomain, code: 0, userInfo: userInfo)

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

        DispatchQueue.global(qos: .userInitiated).async {
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
                "\(ejectList.app.name)_\(ejectList.app.bid)_\(UUID().uuidString.components(separatedBy: "-").last ?? "").zip")

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
