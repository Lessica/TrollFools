//
//  LibraryManagerView.swift
//  TrollFools
//
//  Created by LiBr on 8/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryItem: Identifiable, Hashable {
    enum Kind { case framework, dylib }
    let id: String
    let name: String
    let kind: Kind
    let isUser: Bool
    let fileURL: URL
}

struct LibraryManagerView: View {
    @State private var frameworkItems: [LibraryItem] = []
    @State private var dylibItems: [LibraryItem] = []
    @State private var isImporterPresented: Bool = false
    @State private var importErrorMessage: String? = nil

    var body: some View {
        List {
            if !frameworkItems.isEmpty {
                Section(header: Text(NSLocalizedString("Frameworks", comment: "")).font(.footnote)) {
                    ForEach(frameworkItems) { item in
                        HStack {
                            Image(systemName: item.isUser ? "shippingbox.fill" : "shippingbox")
                                .foregroundColor(item.isUser ? .accentColor : .secondary)
                            Text(item.name)
                                .font(.body)
                            Spacer()
                            if item.isUser {
                                if #available(iOS 15.0, *) {
                                    Button(role: .destructive) {
                                        delete(item: item)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(NSLocalizedString("Delete", comment: ""))
                                } else {
                                    Button(action: {
                                        delete(item: item)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(NSLocalizedString("Delete", comment: ""))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !dylibItems.isEmpty {
                Section(header: Text(NSLocalizedString("Dynamic Libraries", comment: "")).font(.footnote)) {
                    ForEach(dylibItems) { item in
                        HStack {
                            Image(systemName: item.isUser ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                                .foregroundColor(item.isUser ? .accentColor : .secondary)
                            Text(item.name)
                                .font(.body)
                            Spacer()
                            if item.isUser {
                                if #available(iOS 15.0, *) {
                                    Button(role: .destructive) {
                                        delete(item: item)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(NSLocalizedString("Delete", comment: ""))
                                } else {
                                    Button(action: {
                                        delete(item: item)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(NSLocalizedString("Delete", comment: ""))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if frameworkItems.isEmpty && dylibItems.isEmpty {
                Section {
                } footer: {
                    Text(NSLocalizedString("No third-party libraries found in the app bundle.", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Libraries", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(NSLocalizedString("Reload", comment: ""))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("Add Library", comment: ""))
            }
        }
        .onAppear {
            reload()
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.zip]) { result in
            switch result {
            case let .success(url):
                handleImport(url: url)
            case let .failure(error):
                importErrorMessage = error.localizedDescription
            }
        }
        .alert(isPresented: Binding(get: { importErrorMessage != nil }, set: { if !$0 { importErrorMessage = nil } })) {
            Alert(title: Text(NSLocalizedString("Import Failed", comment: "")), message: Text(importErrorMessage ?? ""), dismissButton: .default(Text(NSLocalizedString("OK", comment: ""))))
        }
    }

    private func delete(item: LibraryItem) {
        guard item.isUser else { return }
        do {
            try FileManager.default.removeItem(at: item.fileURL)
            reload()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func reload() {
        let builtinRoot = Bundle.main.bundleURL
        let userRoot = userLibrariesDirectoryURL()
        try? FileManager.default.createDirectory(at: userRoot, withIntermediateDirectories: true)

        var frameworks: [LibraryItem] = []
        var dylibs: [LibraryItem] = []

        func scan(root: URL, isUser: Bool) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for case let url as URL in enumerator {
                guard let isRegular = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular == true else { continue }
                let name = url.lastPathComponent
                // TODO: this check is effectless.
                if name.hasSuffix(".framework.zip") {
                    let module = String(name.dropLast(".framework.zip".count))
                    let item = LibraryItem(id: "framework::\(module)", name: module, kind: .framework, isUser: isUser, fileURL: url)
                    frameworks.removeAll { $0.name.lowercased() == module.lowercased() }
                    frameworks.append(item)
                } else if name.hasSuffix(".dylib.zip") {
                    let dylibName = String(name.dropLast(".zip".count))
                    let item = LibraryItem(id: "dylib::\(dylibName)", name: dylibName, kind: .dylib, isUser: isUser, fileURL: url)
                    dylibs.removeAll { $0.name.lowercased() == dylibName.lowercased() }
                    dylibs.append(item)
                }
            }
        }

        scan(root: builtinRoot, isUser: false)
        scan(root: userRoot, isUser: true)

        frameworks.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        dylibs.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        frameworkItems = frameworks
        dylibItems = dylibs
    }

    private func handleImport(url: URL) {
        let destDir = userLibrariesDirectoryURL()
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let fileName = url.lastPathComponent
        let lower = fileName.lowercased()
        let isFrameworkZip = lower.hasSuffix(".framework.zip")
        let isDylibZip = lower.hasSuffix(".dylib.zip")
        guard isFrameworkZip || isDylibZip else {
            importErrorMessage = NSLocalizedString("Only .framework.zip or .dylib.zip is supported.", comment: "")
            return
        }

        let destURL = destDir.appendingPathComponent(fileName)
        do {
            try? FileManager.default.removeItem(at: destURL)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: url, to: destURL)
            reload()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func userLibrariesDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
            .appendingPathComponent("Libraries", isDirectory: true)
    }
}


