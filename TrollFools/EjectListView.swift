//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import CocoaLumberjackSwift
import SwiftUI
import SwiftUIIntrospect

struct EjectListView: View {

    @StateObject var searchViewModel = AppListSearchViewModel()
    @StateObject var ejectList: EjectListModel

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
    }

    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?

    @State var isDeletingAll = false
    @StateObject var viewControllerHost = ViewControllerHost()

    var deleteAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")
            Spacer()
            if isDeletingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
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

    var headerView: some View {
        Text(ejectList.filteredPlugIns.isEmpty
             ? NSLocalizedString("No Injected Plug-Ins", comment: "")
             : NSLocalizedString("Injected Plug-Ins", comment: ""))
            .font(.footnote)
    }

    var footerView: some View {
        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
            .font(.footnote)
    }

    var ejectListView: some View {
        List {
            Section {
                ForEach(ejectList.filteredPlugIns) { plugin in
                    if #available(iOS 16, *) {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                    } else {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                            .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                if #available(iOS 15, *) {
                    headerView
                } else {
                    headerView
                        .padding(.horizontal, 16)
                }
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if ejectList.app.isFromTroll {
                        if #available(iOS 15, *) {
                            footerView
                        } else {
                            footerView
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: ejectList.filter.isSearching)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(
                    title: NSLocalizedString("Error", comment: ""),
                    error: lastError
                )
            } label: { }
        })
    }

    var body: some View {
        if #available(iOS 15, *) {
            ejectListView
                .onViewWillAppear { viewController in
                    viewControllerHost.viewController = viewController
                }
                .refreshable {
                    withAnimation {
                        ejectList.reload()
                    }
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

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { ejectList.filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }
            try InjectorV3(ejectList.app.url).eject(plugInURLsToRemove)

            ejectList.app.reload()
            ejectList.reload()
        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)

            lastError = error
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try InjectorV3(ejectList.app.url)

            let view = viewControllerHost.viewController?
                .navigationController?.view

            view?.isUserInteractionEnabled = false

            withAnimation {
                isDeletingAll = true
            }

            DispatchQueue.global(qos: .userInteractive).async {
                defer {
                    DispatchQueue.main.async {
                        withAnimation {
                            ejectList.app.reload()
                            ejectList.reload()
                            isDeletingAll = false
                        }

                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.ejectAll()
                } catch {
                    DispatchQueue.main.async {
                        withAnimation {
                            isDeletingAll = false
                        }

                        DDLogError("\(error)", ddlog: InjectorV3.main.logger)

                        lastError = error
                        isErrorOccurred = true
                    }
                }
            }
        } catch {
            lastError = error
            isErrorOccurred = true
        }
    }
}

final class EjectListSearchViewModel: NSObject, UISearchResultsUpdating, ObservableObject {
    @Published var searchKeyword: String = ""

    weak var searchController: UISearchController?

    func updateSearchResults(for searchController: UISearchController) {
        searchKeyword = searchController.searchBar.text ?? ""
    }
}
