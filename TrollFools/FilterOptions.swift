//
//  FilterOptions.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

final class FilterOptions: ObservableObject {
    @Published var searchKeyword = ""
    @Published var showPatchedOnly = false

    var isSearching: Bool { !searchKeyword.isEmpty }

    func reset() {
        searchKeyword = ""
        showPatchedOnly = false
    }
}
