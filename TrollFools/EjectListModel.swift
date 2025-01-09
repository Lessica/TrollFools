//
//  EjectListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import SwiftUI

final class EjectListModel: ObservableObject {
    let app: App
    private var _injectedPlugIns: [InjectedPlugIn] = []

    @Published var filter = FilterOptions()
    @Published var filteredPlugIns: [InjectedPlugIn] = []

    private var cancellables = Set<AnyCancellable>()

    init(_ app: App) {
        self.app = app
        reload()

        $filter
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                withAnimation {
                    self?.performFilter()
                }
            }
            .store(in: &cancellables)
    }

    func reload() {
        self._injectedPlugIns = InjectorV3.main.injectedAssetURLsInBundle(app.url)
            .map { InjectedPlugIn(url: $0) }
        performFilter()
    }

    func performFilter() {
        var filteredPlugIns = _injectedPlugIns

        if !filter.searchKeyword.isEmpty {
            filteredPlugIns = filteredPlugIns.filter {
                $0.url.lastPathComponent.localizedCaseInsensitiveContains(filter.searchKeyword)
            }
        }

        self.filteredPlugIns = filteredPlugIns
    }
}
