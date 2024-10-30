//
//  InjectView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct InjectView: View {
    @EnvironmentObject var vm: AppListModel

    let app: App
    let urlList: [URL]

    @State var injectResult: Result<Void, Error>?
    @StateObject fileprivate var viewControllerHost = ViewControllerHost()

    init(_ app: App, urlList: [URL]) {
        self.app = app
        self.urlList = urlList
    }

    func inject() -> Result<Void, Error> {
        do {
            let injector = try Injector(app.url, appID: app.id, teamID: app.teamID)
            try injector.inject(urlList)
            return .success(())
        } catch {
            NSLog("\(error)")
            return .failure(NSError(domain: kTrollFoolsErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]))
        }
    }

    var bodyContent: some View {
        VStack {
            if let injectResult {
                switch injectResult {
                case .success:
                    SuccessView(title: NSLocalizedString("Completed", comment: ""))

                case .failure(let error):
                    FailureView(title: NSLocalizedString("Failed", comment: ""),
                                message: error.localizedDescription)
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
        if vm.isSelectorMode {
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
