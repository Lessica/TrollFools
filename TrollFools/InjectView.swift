//
//  InjectView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import SwiftUI

struct InjectView: View {
    @EnvironmentObject var appList: AppListModel

    let app: App
    let urlList: [URL]

    @State var injectResult: Result<URL?, Error>?
    @StateObject fileprivate var viewControllerHost = ViewControllerHost()

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy

    init(_ app: App, urlList: [URL]) {
        self.app = app
        self.urlList = urlList
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.bid)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.bid)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.bid)")
    }

    var body: some View {
        if appList.isSelectorMode {
            bodyContent
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("Done", comment: "")) {
                            viewControllerHost.viewController?.navigationController?
                                .dismiss(animated: true)
                        }
                    }
                }
        } else {
            bodyContent
        }
    }

    var bodyContent: some View {
        VStack {
            if let injectResult {
                switch injectResult {
                case let .success(url):
                    SuccessView(
                        title: NSLocalizedString("Completed", comment: ""),
                        logFileURL: url
                    )
                    .onAppear {
                        app.reload()
                    }
                case let .failure(error):
                    FailureView(
                        title: NSLocalizedString("Failed", comment: ""),
                        error: error
                    )
                    .onAppear {
                        app.reload()
                    }
                }
            } else {
                if #available(iOS 16, *) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.all, 20)
                        .controlSize(.large)
                } else {
                    // Fallback on earlier versions
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.all, 20)
                        .scaleEffect(2.0)
                }

                Text(NSLocalizedString("Injecting", comment: ""))
                    .font(.headline)
            }
        }
        .padding()
        .animation(.easeOut, value: injectResult == nil)
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .onViewWillAppear { viewController in
            viewController.navigationController?
                .view.isUserInteractionEnabled = false
            viewControllerHost.viewController = viewController
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = inject()

                DispatchQueue.main.async {
                    injectResult = result
                    app.reload()
                    viewControllerHost.viewController?.navigationController?
                        .view.isUserInteractionEnabled = true
                }
            }
        }
    }

    private func inject() -> Result<URL?, Error> {
        var logFileURL: URL?

        do {
            let injector = try InjectorV3(app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = app.bid
            }

            if injector.teamID.isEmpty {
                injector.teamID = app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            try injector.inject(urlList, shouldPersist: true)
            return .success(injector.latestLogFileURL)

        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)

            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]

            if let logFileURL {
                userInfo[NSURLErrorKey] = logFileURL
            }

            let nsErr = NSError(domain: Constants.gErrorDomain, code: 0, userInfo: userInfo)

            return .failure(nsErr)
        }
    }
}
