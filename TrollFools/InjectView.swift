//
//  InjectView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import SwiftUI

private final class VCHookViewController: UIViewController {
    var onViewWillAppear: ((UIViewController) -> Void)?
    var didTriggered = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didTriggered else {
            return
        }
        onViewWillAppear?(self)
        didTriggered = true
    }
}

private struct VCHookView: UIViewControllerRepresentable {
    typealias UIViewControllerType = VCHookViewController
    let onViewWillAppear: ((UIViewController) -> Void)

    func makeUIViewController(context: Context) -> VCHookViewController {
        let vc = VCHookViewController()
        vc.onViewWillAppear = onViewWillAppear
        return vc
    }

    func updateUIViewController(_ uiViewController: VCHookViewController, context: Context) { }
}

private struct VCHookViewModifier: ViewModifier {
    let onViewWillAppear: ((UIViewController) -> Void)

    func body(content: Content) -> some View {
        content.background(VCHookView(onViewWillAppear: onViewWillAppear))
    }
}

extension View {
    func onViewWillAppear(perform onViewWillAppear: @escaping ((UIViewController) -> Void)) -> some View {
        modifier(VCHookViewModifier(onViewWillAppear: onViewWillAppear))
    }
}

final class ViewControllerHost: ObservableObject {
    weak var viewController: UIViewController?
}

struct InjectView: View {
    let app: App
    let urlList: [URL]

    @State var injectResult: Result<Void, Error>?

    @StateObject var viewControllerHost = ViewControllerHost()

    func inject() -> Result<Void, Error> {
        do {
            let injector = try Injector(bundleURL: app.url, teamID: app.teamID)
            try injector.inject(urlList)
            return .success(())
        } catch {
            DDLogError("\(error)")
            return .failure(NSError(domain: kTrollFoolsErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]))
        }
    }

    var body: some View {
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
                        app.reloadInjectedStatus()
                        viewControllerHost.viewController?.navigationController?
                            .view.isUserInteractionEnabled = true
                    }
                }
            }
        }
    }
}
