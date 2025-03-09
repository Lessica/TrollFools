//
//  AppListSearchModel.swift
//  TrollFools
//
//  Created by 82Flex on 3/8/25.
//

import Combine
import UIKit

final class AppListSearchModel: NSObject, ObservableObject {
    @Published var searchKeyword: String = ""
    @Published var searchScopeIndex: Int = 0

    weak var searchController: UISearchController?
    weak var forwardSearchBarDelegate: (any UISearchBarDelegate)?
}

extension AppListSearchModel: UISearchBarDelegate, UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchKeyword = searchController.searchBar.text ?? ""
    }

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        forwardSearchBarDelegate?.searchBarShouldBeginEditing?(searchBar) ?? true
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarTextDidBeginEditing?(searchBar)
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        forwardSearchBarDelegate?.searchBarShouldEndEditing?(searchBar) ?? true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarTextDidEndEditing?(searchBar)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        forwardSearchBarDelegate?.searchBar?(searchBar, textDidChange: searchText)
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        forwardSearchBarDelegate?.searchBar?(searchBar, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarSearchButtonClicked?(searchBar)
    }

    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarBookmarkButtonClicked?(searchBar)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarCancelButtonClicked?(searchBar)
    }

    func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
        forwardSearchBarDelegate?.searchBarResultsListButtonClicked?(searchBar)
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        searchScopeIndex = selectedScope
        forwardSearchBarDelegate?.searchBar?(searchBar, selectedScopeButtonIndexDidChange: selectedScope)
    }
}
