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
    
    @State var isReplacingPlugin = false
    @State var pluginToReplace: InjectedPlugIn?

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.id)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.id)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.id)")
    }
    
    private func replace(oldPlugin: InjectedPlugIn, with newURL: URL) {
        let view = viewControllerHost.viewController?.navigationController?.view
        view?.isUserInteractionEnabled = false
        
        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    view?.isUserInteractionEnabled = true
                    ejectList.reload()
                }
            }
            
            do {
                let injector = try InjectorV3(ejectList.app.url)
                injector.useWeakReference = useWeakReference
                injector.preferMainExecutable = preferMainExecutable
                injector.injectStrategy = injectStrategy
                
                DDLogInfo("Replacing plugin: Ejecting \(oldPlugin.url.lastPathComponent)", ddlog: injector.logger)
                try injector.eject([oldPlugin.url])
                
                DDLogInfo("Replacing plugin: Injecting \(newURL.lastPathComponent)", ddlog: injector.logger)
                try injector.inject([newURL])

            } catch {
                DDLogError("Failed to replace plugin: \(error)", ddlog: InjectorV3.main.logger)
                DispatchQueue.main.async {
                    self.lastError = error
                    self.isErrorOccurred = true
                }
            }
        }
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
                ForEach(ejectList.filteredPlugIns) { plugin in
                    let cell = PlugInCell(plugin, quickLookExport: $quickLookExport) {
                                self.pluginToReplace = plugin
                                self.isReplacingPlugin = true
                            }
                            .environmentObject(ejectList)
                            
                            if #unavailable(iOS 16) {
                                cell.padding(.vertical, 4)
                            } else {
                                cell
                            }
                        }
                        .onDelete(perform: deletePlugIns)
                    } header: {
                        if #available(iOS 15, *) {
                            Text(ejectList.filteredPlugIns.isEmpty
                                ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                                : NSLocalizedString("Injected Plug-Ins", comment: "")
                            )
                            .font(.footnote)
                            .textCase(nil)
                        } else {
                            HStack {
                                Text(ejectList.filteredPlugIns.isEmpty
                                    ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                                    : NSLocalizedString("Injected Plug-Ins", comment: "")
                                )
                                .font(.footnote)
                                .textCase(nil)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }

            if !ejectList.filter.isSearching && !ejectList.allPlugIns.isEmpty {
                Section {
                    Button(action: ejectList.enableAll) {
                        Label(NSLocalizedString("Enable All", comment: ""), systemImage: "square.stack.3d.up.fill")
                    }
                }
                
                Section {
                    Button(action: { ejectList.disableAll() }) {
                        Label(NSLocalizedString("Disable All", comment: ""), systemImage: "square.stack.3d.up.slash.fill")
                            .foregroundColor(.orange)
                    }
                }
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if #available(iOS 15, *) {
                        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                            .font(.footnote)
                            .textCase(nil)
                            .padding(.vertical, 1)
                    } else {
                        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                            .font(.footnote)
                            .textCase(nil)
                            .padding(.horizontal, 16)
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
        .fileImporter(
            isPresented: $isReplacingPlugin,
            allowedContentTypes: [
                .init(filenameExtension: "dylib")!,
                .init(filenameExtension: "deb")!,
                .bundle,
                .framework,
                .package,
                .zip,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let newURL = urls.first, let oldPlugin = pluginToReplace {
                    replace(oldPlugin: oldPlugin, with: newURL)
                }
            case .failure(let error):
                DDLogError("File importer failed: \(error.localizedDescription)", ddlog: InjectorV3.main.logger)
                self.lastError = error
                self.isErrorOccurred = true
            }
        }
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
            Label(NSLocalizedString("Eject All Permanently", comment: ""), systemImage: "trash")
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
                        urls: ejectList.allPlugIns.map(\.url)
                    ),
                    preview: SharePreview(
                        String(format: NSLocalizedString("%ld Plug-Ins of “%@”", comment: ""), ejectList.allPlugIns.count, ejectList.app.name)
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
                .disabled(ejectList.allPlugIns.isEmpty)
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
                .disabled(ejectList.allPlugIns.isEmpty)
            }
        }
    }

    private func deletePlugIns(at offsets: IndexSet) {
        let plugInsToRemove = offsets.map { ejectList.filteredPlugIns[$0] }
        DispatchQueue.global(qos: .userInitiated).async {
            for plugin in plugInsToRemove {
                try? PluginPersistenceManager.shared.delete(pluginURL: plugin.url, for: ejectList.app)
            }
            DispatchQueue.main.async {
                ejectList.reload()
            }
        }
    }
    
    private func deleteAll() {
        let view = viewControllerHost.viewController?.navigationController?.view
        view?.isUserInteractionEnabled = false
        isDeletingAll = true
        
        let allPlugins = ejectList.allPlugIns
        
        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    isDeletingAll = false
                    view?.isUserInteractionEnabled = true
                    ejectList.reload()
                }
            }

            for plugin in allPlugins {
                do {
                    try PluginPersistenceManager.shared.delete(pluginURL: plugin.url, for: ejectList.app)
                } catch {
                    DDLogError("Failed to delete plugin \(plugin.url.lastPathComponent): \(error)", ddlog: InjectorV3.main.logger)
                    DispatchQueue.main.async {
                        self.lastError = error
                        self.isErrorOccurred = true
                    }
                }
            }
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
        
        for plugin in ejectList.allPlugIns {
            let exportTargetURL = exportURL.appendingPathComponent(plugin.url.lastPathComponent)
            try fileMgr.copyItem(at: plugin.url, to: exportTargetURL)
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

