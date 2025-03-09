//
//  FilterOptions.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

struct FilterOptions: Hashable {
    var searchKeyword = ""
    var showPatchedOnly = false

    var isSearching: Bool { !searchKeyword.isEmpty }

    mutating func reset() {
        searchKeyword = ""
        showPatchedOnly = false
    }
}
