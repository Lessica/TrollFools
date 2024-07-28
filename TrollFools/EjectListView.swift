//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import CocoaLumberjackSwift
import Combine
import SwiftUI

private let gDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct InjectedPlugIn: Identifiable {
    let id = UUID()
    let url: URL
    let createdAt: Date

    init(url: URL) {
        self.url = url
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.createdAt = attributes?[.creationDate] as? Date ?? Date()
    }
}

struct PlugInCell: View {
    let plugIn: InjectedPlugIn

    @EnvironmentObject var filter: FilterOptions

    @available(iOS 15.0, *)
    var highlightedName: AttributedString {
        let name = plugIn.url.lastPathComponent
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    var iconName: String {
        let pathExt = plugIn.url.pathExtension.lowercased()
        if pathExt == "bundle" {
            return "archivebox"
        }
        if pathExt == "dylib" {
            return "bandage"
        }
        if pathExt == "framework" {
            return "shippingbox"
        }
        return "puzzlepiece"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                if #available(iOS 15.0, *) {
                    Text(highlightedName)
                        .font(.headline)
                } else {
                    Text(plugIn.url.lastPathComponent)
                        .font(.headline)
                }

                Text(gDateFormatter.string(from: plugIn.createdAt))
                    .font(.subheadline)
            }
        }
        .contextMenu {
            if isFilzaInstalled {
                Button {
                    openInFilza()
                } label: {
                    Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
                }
            }
        }
    }

    var isFilzaInstalled: Bool { AppListModel.shared.isFilzaInstalled }

    private func openInFilza() {
        AppListModel.shared.openInFilza(plugIn.url)
    }
}

final class EjectListModel: ObservableObject {
    let app: App
    private var _injectedPlugIns: [InjectedPlugIn] = []

    @Published var filter = FilterOptions()
    @Published var filteredPlugIns: [InjectedPlugIn] = []

    private var cancellables = Set<AnyCancellable>()

    init(_ app: App) {
        self.app = app
        reload()

        filter.$searchKeyword
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                withAnimation {
                    self?.performFilter()
                }
            }
            .store(in: &cancellables)
    }

    func reload() {
        self._injectedPlugIns = Injector.injectedPlugInURLs(app.url)
            .map { InjectedPlugIn(url: $0) }
        performFilter()
    }

    func performFilter() {
        var filteredPlugIns = _injectedPlugIns

        if !filter.searchKeyword.isEmpty {
            filteredPlugIns = filteredPlugIns.filter {
                $0.url.lastPathComponent.localizedCaseInsensitiveContains(filter.searchKeyword)
            }
        }

        self.filteredPlugIns = filteredPlugIns
    }
}

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
            DDLogError("\(error)")

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

                        DDLogError("\(error)")

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
