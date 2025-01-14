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

    init(_ app: App, urlList: [URL]) {
        self.app = app
        self.urlList = urlList
    }

    func inject() -> Result<URL?, Error> {
        var logFileURL: URL?

        do {
            let injector = try InjectorV3(app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = app.id
            }

            if injector.teamID.isEmpty {
                injector.teamID = app.teamID
            }

            try injector.inject(urlList)
            return .success(injector.latestLogFileURL)

        } catch {

            DDLogError("\(error)", ddlog: InjectorV3.main.logger)

            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]

            if let logFileURL {
                userInfo[NSURLErrorKey] = logFileURL
            }

            return .failure(NSError(domain: gTrollFoolsErrorDomain, code: 0, userInfo: userInfo))
        }
    }

    var bodyContent: some View {
        VStack {
            if let injectResult {
                switch injectResult {
                case .success(let url):
                    SuccessView(
                        title: NSLocalizedString("Completed", comment: ""),
                        logFileURL: url
                    )
                case .failure(let error):
                    FailureView(
                        title: NSLocalizedString("Failed", comment: ""),
                        error: error
                    )
                }
            } else {
                if #available(iOS 16.0, *) {
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
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .onViewWillAppear { viewController in
            viewController.navigationController?
                .view.isUserInteractionEnabled = false
            viewControllerHost.viewController = viewController
        }
        .onAppear {
            DispatchQueue.global(qos: .userInteractive).async {
                let result = inject()

                DispatchQueue.main.async {
                    withAnimation {
                        injectResult = result
                        app.reload()
                        viewControllerHost.viewController?.navigationController?
                            .view.isUserInteractionEnabled = true
                    }
                }
            }
        }
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
}
