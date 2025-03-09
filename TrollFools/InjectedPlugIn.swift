//
//  InjectedPlugIn.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

struct InjectedPlugIn: Identifiable, Hashable {
    let id: String
    let url: URL
    let createdAt: Date

    init(url: URL) {
        self.id = url.absoluteString
        self.url = url
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.createdAt = attributes?[.creationDate] as? Date ?? Date()
    }
}
