//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import CocoaLumberjackSwift
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

    @EnvironmentObject var searchOptions: SearchOptions

    @available(iOS 15.0, *)
    var highlightedName: AttributedString {
        let name = plugIn.url.lastPathComponent
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: searchOptions.keyword, options: [.caseInsensitive, .diacriticInsensitive]) {
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
    }
}

struct EjectListView: View {
    let app: App

    init(_ app: App) {
        self.app = app
    }

    @State var injectedPlugIns: [InjectedPlugIn] = []
    @State var isErrorOccurred: Bool = false
    @State var errorMessage: String = ""

    @State var searchResults: [InjectedPlugIn] = []
    @StateObject var searchOptions = SearchOptions()

    @State var isDeletingAll = false
    @StateObject var viewControllerHost = ViewControllerHost()

    var isSearching: Bool {
        return !searchOptions.keyword.isEmpty
    }

    var filteredPlugIns: [InjectedPlugIn] {
        isSearching ? searchResults : injectedPlugIns
    }

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
                ForEach(filteredPlugIns) { plugin in
                    if #available(iOS 16.0, *) {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(searchOptions)
                    } else {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(searchOptions)
                            .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text(filteredPlugIns.isEmpty
                     ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                     : NSLocalizedString("Injected Plug-Ins", comment: ""))
                    .font(.footnote)
            }

            if !isSearching && !filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    NavigationLink(isActive: $isErrorOccurred) {
                        FailureView(title: NSLocalizedString("Error", comment: ""),
                                    message: errorMessage)
                    } label: { }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onViewWillAppear { viewController in
            viewControllerHost.viewController = viewController
        }
        .onAppear {
            reloadPlugIns()
        }
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            ejectList
                .refreshable {
                    withAnimation {
                        reloadPlugIns()
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
            ejectList
        }
    }

    func reloadPlugIns() {
        searchOptions.reset()
        injectedPlugIns = Injector.injectedPlugInURLs(app.url)
            .map { InjectedPlugIn(url: $0) }
    }

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }
            let injector = try Injector(bundleURL: app.url, teamID: app.teamID)
            try injector.eject(plugInURLsToRemove)

            app.reloadInjectedStatus()
            reloadPlugIns()
        } catch {
            DDLogError("\(error)")

            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try Injector(bundleURL: app.url, teamID: app.teamID)

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
                            app.reloadInjectedStatus()
                            reloadPlugIns()
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

    func fetchSearchResults(for query: String) {
        searchResults = injectedPlugIns.filter { plugin in
            plugin.url.lastPathComponent.localizedCaseInsensitiveContains(query)
        }
    }
}
