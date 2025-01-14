//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import CocoaLumberjackSwift
import SwiftUI

struct EjectListView: View {
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
        if #available(iOS 15.0, *) {
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

    var ejectListView: some View {
        List {
            Section {
                ForEach(ejectList.filteredPlugIns) { plugin in
                    if #available(iOS 16.0, *) {
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
                Text(ejectList.filteredPlugIns.isEmpty
                     ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                     : NSLocalizedString("Injected Plug-Ins", comment: ""))
                    .font(.footnote)
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if ejectList.app.isFromTroll {
                        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                            .font(.footnote)
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
        .onViewWillAppear { viewController in
            viewControllerHost.viewController = viewController
        }
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            ejectListView
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
