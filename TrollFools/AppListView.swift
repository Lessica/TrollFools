//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appList: AppListModel

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
%@ %@ %@ © 2024-2025
%@
""", appNameString, appVersionString, NSLocalizedString("Copyright", comment: ""), NSLocalizedString("Made with ♥ by OwnGoal Studio", comment: ""))
    }

    let repoURL = URL(string: "https://github.com/Lessica/TrollFools")

    func filteredAppList(_ apps: [App]) -> some View {
        ForEach(apps, id: \.id) { app in
            NavigationLink {
                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                    InjectView(app, urlList: [selectorURL])
                } else {
                    OptionView(app)
                }
            } label: {
                if #available(iOS 16.0, *) {
                    AppListCell(app: app)
                } else {
                    AppListCell(app: app)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    var appListFooterView: some View {
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

    var appListView: some View {
        List {
            if AppListModel.hasTrollStore && appList.isRebuildNeeded {
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

                            if appList.isRebuilding {
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
                    .disabled(appList.isRebuilding)
                }
            }

            Section {
                filteredAppList(appList.userApplications)
            } header: {
                Text(NSLocalizedString("User Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !appList.filter.isSearching && !appList.filter.showPatchedOnly && appList.unsupportedCount > 0 {
                    Text(String(format: NSLocalizedString("And %d more unsupported user applications.", comment: ""), appList.unsupportedCount))
                        .font(.footnote)
                }
            }

            Section {
                filteredAppList(appList.trollApplications)
            } header: {
                Text(NSLocalizedString("TrollStore Applications", comment: ""))
                    .font(.footnote)
            }

            Section {
                filteredAppList(appList.appleApplications)
            } header: {
                Text(NSLocalizedString("Injectable System Applications", comment: ""))
                    .font(.footnote)
            } footer: {
                if !appList.filter.isSearching {
                    VStack(alignment: .leading, spacing: 20) {
                        if !appList.filter.showPatchedOnly {
                            Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                                .font(.footnote)
                        }

                        if !appList.isSelectorMode {
                            if #available(iOS 16.0, *) {
                                appListFooterView
                                    .padding(.top, 8)
                            } else {
                                appListFooterView
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(appList.isSelectorMode ? NSLocalizedString("Select Application to Inject", comment: "") : NSLocalizedString("TrollFools", comment: ""))
        .navigationBarTitleDisplayMode(appList.isSelectorMode ? .inline : .automatic)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(title: NSLocalizedString("Error", comment: ""),
                            message: errorMessage)
            } label: { }
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                    VStack {
                        Text(selectorURL.lastPathComponent).font(.headline)
                        Text(NSLocalizedString("Select Application to Inject", comment: "")).font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appList.filter.showPatchedOnly.toggle()
                } label: {
                    if #available(iOS 15.0, *) {
                        Image(systemName: appList.filter.showPatchedOnly 
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    } else {
                        Image(systemName: appList.filter.showPatchedOnly 
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
                appListView
                    .refreshable {
                        withAnimation {
                            appList.reload()
                        }
                    }
                    .searchable(
                        text: $appList.filter.searchKeyword,
                        placement: .automatic,
                        prompt: (appList.filter.showPatchedOnly
                                 ? NSLocalizedString("Search Patched…", comment: "")
                                 : NSLocalizedString("Search…", comment: ""))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            } else {
                // Fallback on earlier versions
                appListView
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
            appList.isRebuilding = true
        }

        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuilding = false
                    }
                }
            }

            do {
                try appList.rebuildIconCache()

                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuildNeeded = false
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
