//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct AppListView: View {
    @EnvironmentObject var vm: AppListModel

    @State var isErrorOccurred: Bool = false
    @State var errorMessage: String = ""

    @State var selectorOpenedURL: URL? = nil

    var appNameString: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrollFools"
    }

    var appVersionString: String {
        String(format: "v%@ (%@)",
               Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
               Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")
    }

    var appString: String {
        String(format: """
%@ %@ %@ © 2024
%@
""", appNameString, appVersionString, NSLocalizedString("Copyright", comment: ""), NSLocalizedString("Made with ♥ by OwnGoal Studio", comment: ""))
    }

    let repoURL = URL(string: "https://github.com/Lessica/TrollFools")

    func filteredAppList(_ apps: [App]) -> some View {
        ForEach(apps, id: \.id) { app in
            NavigationLink {
                if vm.isSelectorMode, let selectorURL = vm.selectorURL {
                    InjectView(app, urlList: [selectorURL])
                } else {
                    OptionView(app)
                }
            } label: {
                if #available(iOS 16.0, *) {
                    AppListCell(app: app)
                        .environmentObject(vm.filter)
                } else {
                    AppListCell(app: app)
                        .environmentObject(vm.filter)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    var appListFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            Button {
                if let repoURL {
                    UIApplication.shared.open(repoURL)
                }
            } label: {
                Text(NSLocalizedString("Source Code", comment: ""))
                    .font(.footnote)
            }
        }
    }

    var appList: some View {
        List {
            if AppListModel.hasTrollStore && vm.isRebuildNeeded {
                Section {
                    Button {
                        rebuildIconCache()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Rebuild Icon Cache", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(NSLocalizedString("You need to rebuild the icon cache in TrollStore to apply changes.", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if vm.isRebuilding {
                                if #available(iOS 16.0, *) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .controlSize(.large)
                                } else {
                                    // Fallback on earlier versions
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(2.0)
                                }
                            } else {
                                Image(systemName: "timelapse")
                                    .font(.title)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(vm.isRebuilding)
                }
            }

            Section {
                filteredAppList(vm.userApplications)
            } header: {
                Text(NSLocalizedString("User Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !vm.filter.isSearching && !vm.filter.showPatchedOnly && vm.unsupportedCount > 0 {
                    Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), vm.unsupportedCount))
                        .font(.footnote)
                }
            }

            Section {
                filteredAppList(vm.trollApplications)
            } header: {
                Text(NSLocalizedString("TrollStore Applications", comment: ""))
                    .font(.footnote)
            }

            Section {
                filteredAppList(vm.appleApplications)
            } header: {
                Text(NSLocalizedString("Injectable System Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !vm.filter.isSearching {
                    VStack(alignment: .leading, spacing: 20) {
                        if !vm.filter.showPatchedOnly {
                            Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                                .font(.footnote)
                        }

                        if !vm.isSelectorMode {
                            if #available(iOS 16.0, *) {
                                appListFooter
                                    .padding(.top, 8)
                            } else {
                                appListFooter
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vm.isSelectorMode ? NSLocalizedString("Select Application to Inject", comment: "") : NSLocalizedString("TrollFools", comment: ""))
        .navigationBarTitleDisplayMode(vm.isSelectorMode ? .inline : .automatic)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(title: NSLocalizedString("Error", comment: ""),
                            message: errorMessage)
            } label: { }
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.isSelectorMode, let selectorURL = vm.selectorURL {
                    VStack {
                        Text(selectorURL.lastPathComponent).font(.headline)
                        Text(NSLocalizedString("Select Application to Inject", comment: "")).font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.filter.showPatchedOnly.toggle()
                } label: {
                    if #available(iOS 15.0, *) {
                        Image(systemName: vm.filter.showPatchedOnly 
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    } else {
                        Image(systemName: vm.filter.showPatchedOnly 
                              ? "eject.circle.fill"
                              : "eject.circle")
                    }
                }
                .accessibilityLabel(NSLocalizedString("Show Patched Only", comment: ""))
            }
        }
    }

    var body: some View {
        NavigationView {
            if #available(iOS 15.0, *) {
                appList
                    .refreshable {
                        withAnimation {
                            vm.reload()
                        }
                    }
                    .searchable(
                        text: $vm.filter.searchKeyword,
                        placement: .automatic,
                        prompt: (vm.filter.showPatchedOnly
                                 ? NSLocalizedString("Search Patched…", comment: "")
                                 : NSLocalizedString("Search…", comment: ""))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } else {
                // Fallback on earlier versions
                appList
            }
        }
        .sheet(item: $selectorOpenedURL) { url in
            AppListView()
                .environmentObject(AppListModel(selectorURL: url))
        }
        .onOpenURL { url in
            guard url.isFileURL, url.pathExtension.lowercased() == "dylib" else {
                return
            }
            selectorOpenedURL = preprocessURL(url)
        }
    }

    private func rebuildIconCache() {
        withAnimation {
            vm.isRebuilding = true
        }

        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    withAnimation {
                        vm.isRebuilding = false
                    }
                }
            }

            do {
                try vm.rebuildIconCache()

                DispatchQueue.main.async {
                    withAnimation {
                        vm.isRebuildNeeded = false
                    }
                }
            } catch {
                NSLog("\(error.localizedDescription)")

                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isErrorOccurred = true
                }
            }
        }
    }

    private func preprocessURL(_ url: URL) -> URL {
        let isInbox = url.path.contains("/Documents/Inbox/")
        guard isInbox else {
            return url
        }
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileNameComps = fileNameNoExt.components(separatedBy: CharacterSet(charactersIn: "._- "))
        guard let lastComp = fileNameComps.last, fileNameComps.count > 1, lastComp.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return url
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(String(fileNameNoExt.prefix(fileNameNoExt.count - lastComp.count - 1)))
            .appendingPathExtension(url.pathExtension)
        do {
            try? FileManager.default.removeItem(at: newURL)
            try FileManager.default.copyItem(at: url, to: newURL)
            return newURL
        } catch {
            return url
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
