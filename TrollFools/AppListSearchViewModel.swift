//
//  AppListSearchViewModel.swift
//  TrollFools
//
//  Created by 82Flex on 3/8/25.
//

import Combine
import UIKit

final class AppListSearchViewModel: NSObject, ObservableObject {
    @Published var searchKeyword: String = ""
    @Published var searchScopeIndex: Int = 0

    weak var searchController: UISearchController?
}

extension AppListSearchViewModel: UISearchBarDelegate, UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchKeyword = searchController.searchBar.text ?? ""
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        searchScopeIndex = selectedScope
    }
}
