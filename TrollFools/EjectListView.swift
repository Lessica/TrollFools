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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text(plugIn.url.lastPathComponent)
                    .font(.headline)

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

    var body: some View {
        List {
            Section {
                ForEach(injectedPlugIns) { plugin in
                    PlugInCell(plugIn: plugin)
                }
                .onDelete(perform: delete)
            } header: {
                Text(injectedPlugIns.isEmpty
                     ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                     : NSLocalizedString("Injected Plug-Ins", comment: ""))
                    .font(.footnote)

                NavigationLink(isActive: $isErrorOccurred) {
                    FailureView(title: NSLocalizedString("Error", comment: ""),
                                message: errorMessage)
                } label: { }
            }

            if !injectedPlugIns.isEmpty {
                Section {
                    Button(action: {
                        withAnimation {
                            deleteAll()
                        }
                    }) {
                        Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadPlugIns()
        }
    }

    func reloadPlugIns() {
        injectedPlugIns = Injector.injectedPlugInURLs(app.url)
            .map { InjectedPlugIn(url: $0) }
    }

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { injectedPlugIns[$0] }
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
}
