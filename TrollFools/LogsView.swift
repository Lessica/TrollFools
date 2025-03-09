//
//  LogsView.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/14.
//

import SwiftUI

struct LogsView: UIViewControllerRepresentable {

    let url: URL

    typealias UIViewControllerType = UINavigationController

    func makeUIViewController(context: Context) -> UINavigationController {

        let viewController = StripedTextTableViewController(path: url.path)

        viewController.autoReload = false
        viewController.maximumNumberOfRows = 1000
        viewController.maximumNumberOfLines = 20
        viewController.reversed = true
        viewController.allowDismissal = true
        viewController.allowTrash = false
        viewController.allowSearch = true
        viewController.allowShare = true
        viewController.allowMultiline = true
        viewController.pullToReload = false
        viewController.tapToCopy = true
        viewController.pressToCopy = true
        viewController.preserveEmptyLines = false
        viewController.removeDuplicates = true

        if let regex = try? NSRegularExpression(pattern: "^\\d{4}\\/\\d{2}\\/\\d{2} \\d{2}:\\d{2}:\\d{2}:\\d{3}  ") {
            viewController.rowPrefixRegularExpression = regex
        }

        let navController = UINavigationController(rootViewController: viewController)
        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
}
