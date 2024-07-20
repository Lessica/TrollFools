//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import SwiftUI

let gDateFormatter: DateFormatter = {
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
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

    var isSearching: Bool {
        return !searchOptions.keyword.isEmpty
    }

    var filteredPlugIns: [InjectedPlugIn] {
        isSearching ? searchResults : injectedPlugIns
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
                    Button(action: {
                        withAnimation {
                            deleteAll()
                        }
                    }) {
                        Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")
                    }
                    .foregroundColor(.red)
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
            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try Injector(bundleURL: app.url, teamID: app.teamID)
            try injector.ejectAll()
            app.reloadInjectedStatus()
            reloadPlugIns()
        } catch {
            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }

    private func fetchSearchResults(for query: String) {
        searchResults = injectedPlugIns.filter { plugin in
            plugin.url.lastPathComponent.localizedCaseInsensitiveContains(query)
        }
    }
}
