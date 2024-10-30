//
//  ViewControllerHost.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI

final class ViewControllerHost: ObservableObject {
    weak var viewController: UIViewController?
}

extension View {
    func onViewWillAppear(perform onViewWillAppear: @escaping ((UIViewController) -> Void)) -> some View {
        modifier(VCHookViewModifier(onViewWillAppear: onViewWillAppear))
    }
}

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
