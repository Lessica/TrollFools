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
    private(set) var allPlugIns: [InjectedPlugIn] = []

    @Published var filter = FilterOptions()
    @Published var filteredPlugIns: [InjectedPlugIn] = []
    @Published var lastOperationError: Error? = nil

    @Published var isOperationInProgress: Bool = false
    private let operationQueue = DispatchQueue(label: "wiki.qaq.trollfools.plugin-operations")

    private var cancellables = Set<AnyCancellable>()

    init(_ app: App) {
        self.app = app
        reload()
        $filter
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.performFilter()
            }
            .store(in: &cancellables)
    }

    func reload() {
        let enabledPluginURLs = InjectorV3.main.injectedAssetURLsInBundle(app.url)
        var finalPlugins = enabledPluginURLs.map { InjectedPlugIn(url: $0, isEnabled: true) }

        let enabledPluginNames = Set(enabledPluginURLs.map { $0.lastPathComponent })
        let persistentPluginURLs = PluginPersistenceManager.shared.getDisabledPluginURLs(for: app.id)

        for persistentURL in persistentPluginURLs {
            if !enabledPluginNames.contains(persistentURL.lastPathComponent) {
                let disabledPlugin = InjectedPlugIn(url: persistentURL, isEnabled: false)
                finalPlugins.append(disabledPlugin)
            }
        }

        self.allPlugIns = finalPlugins.sorted {
            $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }

        performFilter()
        app.reload()
    }

    private func runOperation(_ operation: @escaping () throws -> Void) {
        guard !isOperationInProgress else { return }

        DispatchQueue.main.async {
            self.lastOperationError = nil
            self.isOperationInProgress = true
        }

        operationQueue.async {
            var caughtError: Error?
            do {
                try operation()
            } catch {
                print("An error occurred during plugin operation: \(error)")
                caughtError = error
            }

            DispatchQueue.main.async {
                self.reload()
                self.isOperationInProgress = false
                if let error = caughtError {
                    self.lastOperationError = error
                }
            }
        }
    }

    func toggleEnableState(for plugin: InjectedPlugIn) {
        runOperation {
            if plugin.isEnabled {
                try PluginPersistenceManager.shared.disable(pluginURL: plugin.url, for: self.app)
            } else {
                try PluginPersistenceManager.shared.enable(pluginURL: plugin.url, for: self.app)
            }
        }
    }

    func enableAll() {
        runOperation {
            let urlsToEnable = self.allPlugIns.filter { !$0.isEnabled }.map { $0.url }
            guard !urlsToEnable.isEmpty else { return }
            let injector = try InjectorV3(self.app.url)
            try injector.inject(urlsToEnable)
        }
    }

    func disableAll() {
        runOperation {
            let urlsToDisable = self.allPlugIns.filter { $0.isEnabled }.map { $0.url }
            guard !urlsToDisable.isEmpty else { return }
            
            let injector = try InjectorV3(self.app.url)
            for pluginURL in urlsToDisable {
                let persistentDir = PluginPersistenceManager.shared.getDisabledDirectory(for: self.app.id)
                try? FileManager.default.createDirectory(at: persistentDir, withIntermediateDirectories: true, attributes: nil)
                let persistentDestinationURL = persistentDir.appendingPathComponent(pluginURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: persistentDestinationURL.path) {
                    try? injector.cmdCopy(from: pluginURL, to: persistentDestinationURL, overwrite: false)
                }
            }
            
            try injector.eject(urlsToDisable)
        }
    }

    func delete(plugins: [InjectedPlugIn]) {
        runOperation {
            for plugin in plugins {
                try PluginPersistenceManager.shared.delete(pluginURL: plugin.url, for: self.app)
            }
        }
    }
    
    func deleteAll() {
        runOperation {
            for plugin in self.allPlugIns {
                try PluginPersistenceManager.shared.delete(pluginURL: plugin.url, for: self.app)
            }
        }
    }

    func performFilter() {
        var filtered = allPlugIns
        if !filter.searchKeyword.isEmpty {
            filtered = filtered.filter {
                $0.url.lastPathComponent.localizedCaseInsensitiveContains(filter.searchKeyword)
            }
        }
        self.filteredPlugIns = filtered
    }
}
