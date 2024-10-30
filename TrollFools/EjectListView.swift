//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import SwiftUI

struct EjectListView: View {
    @StateObject var vm: EjectListModel

    init(_ app: App) {
        _vm = StateObject(wrappedValue: EjectListModel(app))
    }

    @State var isErrorOccurred: Bool = false
    @State var errorMessage: String = ""

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

    var ejectList: some View {
        List {
            Section {
                ForEach(vm.filteredPlugIns) { plugin in
                    if #available(iOS 16.0, *) {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(vm.filter)
                    } else {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(vm.filter)
                            .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text(vm.filteredPlugIns.isEmpty
                     ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                     : NSLocalizedString("Injected Plug-Ins", comment: ""))
                    .font(.footnote)
            }

            if !vm.filter.isSearching && !vm.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if vm.app.isFromTroll {
                        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                            .font(.footnote)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: vm.filter.isSearching)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(title: NSLocalizedString("Error", comment: ""),
                            message: errorMessage)
            } label: { }
        })
        .onViewWillAppear { viewController in
            viewControllerHost.viewController = viewController
        }
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            ejectList
                .refreshable {
                    withAnimation {
                        vm.reload()
                    }
                }
                .searchable(
                    text: $vm.filter.searchKeyword,
                    placement: .automatic,
                    prompt: NSLocalizedString("Search…", comment: "")
                )
                .textInputAutocapitalization(.never)
        } else {
            // Fallback on earlier versions
            ejectList
        }
    }

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { vm.filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }
            let injector = try Injector(vm.app.url, appID: vm.app.id, teamID: vm.app.teamID)
            try injector.eject(plugInURLsToRemove)

            vm.app.reload()
            vm.reload()
        } catch {
            NSLog("\(error)")

            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try Injector(vm.app.url, appID: vm.app.id, teamID: vm.app.teamID)

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
                            vm.app.reload()
                            vm.reload()
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

                        NSLog("\(error)")

                        errorMessage = error.localizedDescription
                        isErrorOccurred = true
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }
}
