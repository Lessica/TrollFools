//
//  EjectListSearchModel.swift
//  TrollFools
//
//  Created by Rachel on 9/3/2025.
//

import Combine
import Foundation

final class EjectListSearchViewModel: NSObject, UISearchResultsUpdating, ObservableObject {
    @Published var searchKeyword: String = ""

    weak var searchController: UISearchController?

    func updateSearchResults(for searchController: UISearchController) {
        searchKeyword = searchController.searchBar.text ?? ""
    }
}
