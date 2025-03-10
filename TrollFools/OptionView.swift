//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct OptionView: View {
    let app: App

    @State var isImporterPresented = false
    @State var isImporterSelected = false

    @State var isWarningPresented = false
    @State var temporaryResult: Result<[URL], any Error>?

    @State var isSettingsPresented = false

    @State var importerResult: Result<[URL], any Error>?

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    init(_ app: App) {
        self.app = app
    }

    var body: some View {
        if #available(iOS 15, *) {
            content
                .alert(
                    NSLocalizedString("Notice", comment: ""),
                    isPresented: $isWarningPresented,
                    presenting: temporaryResult
                ) { result in
                    Button {
                        importerResult = result
                        isImporterSelected = true
                    } label: {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    Button(role: .destructive) {
                        importerResult = result
                        isImporterSelected = true
                        isWarningHidden = true
                    } label: {
                        Text(NSLocalizedString("Continue and Don’t Show Again", comment: ""))
                    }
                    Button(role: .cancel) {
                        temporaryResult = nil
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    if case .success(let urls) = $0 {
                        Text(Self.warningMessage(urls))
                    }
                }
        } else {
            content
        }
    }

    var content: some View {
        VStack(spacing: 80) {
            HStack {
                Spacer()

                Button {
                    isImporterPresented = true
                } label: {
                    OptionCell(option: .attach)
                }
                .accessibilityLabel(NSLocalizedString("Inject", comment: ""))

                Spacer()

                NavigationLink {
                    EjectListView(app)
                } label: {
                    OptionCell(option: .detach)
                }
                .accessibilityLabel(NSLocalizedString("Eject", comment: ""))

                Spacer()
            }

            Button {
                isSettingsPresented = true
            } label: {
                Label(NSLocalizedString("Advanced Settings", comment: ""),
                      systemImage: "gear")
            }
        }
        .padding()
        .navigationTitle(app.name)
        .background(Group {
            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case .success(let urls):
                        InjectView(app, urlList: urls
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }))
                    case .failure(let error):
                        FailureView(
                            title: NSLocalizedString("Error", comment: ""),
                            error: error
                        )
                    }
                }
            } label: { }
        })
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                .init(filenameExtension: "dylib")!,
                .init(filenameExtension: "deb")!,
                .bundle,
                .framework,
                .package,
                .zip,
            ],
            allowsMultipleSelection: true
        ) {
            result in
            switch result {
            case .success(let theSuccess):
                if !isWarningHidden && theSuccess.contains(where: { $0.pathExtension.lowercased() == "deb" }) {
                    temporaryResult = result
                    isWarningPresented = true
                } else {
                    importerResult = result
                    isImporterSelected = true
                }
            case .failure:
                importerResult = result
                isImporterSelected = true
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            if #available(iOS 16, *) {
                SettingsView(app)
                    .presentationDetents([.medium, .large])
            } else {
                SettingsView(app)
            }
        }
    }

    static func warningMessage(_ urls: [URL]) -> String {
        guard let firstDylibName = urls.first(where: { $0.pathExtension.lowercased() == "deb" })?.lastPathComponent else {
            fatalError("No debian package found.")
        }
        return String(format: NSLocalizedString("You’ve selected at least one Debian Package “%@”. We’re here to remind you that it will not work as it was in a jailbroken environment. Please make sure you know what you’re doing.", comment: ""), firstDylibName)
    }
}
