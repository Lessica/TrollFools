//
//  InjectedPlugIn.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

struct InjectedPlugIn: Equatable, Identifiable, Hashable {
    let id: String
    let url: URL
    let createdAt: Date
    let isEnabled: Bool

    init(url: URL, isEnabled: Bool) {
        self.id = url.absoluteString
        self.url = url
        self.createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        self.isEnabled = isEnabled
    }
}
