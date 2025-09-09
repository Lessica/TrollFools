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

    func toggleEnableState(for plugin: InjectedPlugIn) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(self.app.url)
                injector.terminateApp()
                
                if plugin.isEnabled {
                    try PluginPersistenceManager.shared.disable(pluginURL: plugin.url, for: self.app)
                } else {
                    try PluginPersistenceManager.shared.enable(pluginURL: plugin.url, for: self.app)
                }
            } catch {
                print("Error toggling plugin state: \(error)")
            }
            DispatchQueue.main.async {
                self.reload()
            }
        }
    }

    func enableAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pluginsToEnable = self.allPlugIns.filter { !$0.isEnabled }
            let urlsToEnable = pluginsToEnable.map { $0.url }

            guard !urlsToEnable.isEmpty else { return }

            do {
                let injector = try InjectorV3(self.app.url)
                try injector.inject(urlsToEnable)
            } catch {
                print("Error enabling all plugins: \(error)")
            }

            DispatchQueue.main.async {
                self.reload()
            }
        }
    }

    func disableAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pluginsToDisable = self.allPlugIns.filter { $0.isEnabled }
            let urlsToDisable = pluginsToDisable.map { $0.url }

            guard !urlsToDisable.isEmpty else { return }

            let injector = try? InjectorV3(self.app.url)
            for pluginURL in urlsToDisable {
                let persistentDir = PluginPersistenceManager.shared.getDisabledDirectory(for: self.app.id)
                try? FileManager.default.createDirectory(at: persistentDir, withIntermediateDirectories: true, attributes: nil)
                let persistentDestinationURL = persistentDir.appendingPathComponent(pluginURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: persistentDestinationURL.path) {
                    try? injector?.cmdCopy(from: pluginURL, to: persistentDestinationURL, overwrite: false)
                }
            }
            
            do {
                guard let injector = injector else { return }
                try injector.eject(urlsToDisable)
            } catch {
                print("Error disabling all plugins: \(error)")
            }

            DispatchQueue.main.async {
                self.reload()
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
