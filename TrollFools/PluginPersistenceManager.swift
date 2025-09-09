//
//  PluginPersistenceManager.swift
//  TrollFools
//
//
//

import Foundation

final class PluginPersistenceManager {
    static let shared = PluginPersistenceManager()
    private let persistentPluginsRootURL = URL(fileURLWithPath: "/var/mobile/Library/TrollFools/PersistentPlugins")

    private init() {
        try? FileManager.default.createDirectory(at: persistentPluginsRootURL, withIntermediateDirectories: true, attributes: nil)
    }

    func getDisabledDirectory(for appID: String) -> URL {
        return persistentPluginsRootURL.appendingPathComponent(appID, isDirectory: true)
    }

    func disable(pluginURL: URL, for app: App) throws {
        let injector = try InjectorV3(app.url)

        let persistentDir = getDisabledDirectory(for: app.id)
        try? FileManager.default.createDirectory(at: persistentDir, withIntermediateDirectories: true, attributes: nil)
        let persistentDestinationURL = persistentDir.appendingPathComponent(pluginURL.lastPathComponent)

        if !FileManager.default.fileExists(atPath: persistentDestinationURL.path) {
            try injector.cmdCopy(from: pluginURL, to: persistentDestinationURL, overwrite: false)
        }

        try injector.eject([pluginURL])
    }

    func enable(pluginURL: URL, for app: App) throws {
        let injector = try InjectorV3(app.url)
        try injector.inject([pluginURL])
    }

    func getDisabledPluginURLs(for appID: String) -> [URL] {
        let disabledDir = getDisabledDirectory(for: appID)
        guard let urls = try?
                FileManager.default.contentsOfDirectory(at: disabledDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }
        return urls
    }

    func delete(pluginURL: URL, for app: App) throws {
        let injector = try InjectorV3(app.url)
        let pluginName = pluginURL.lastPathComponent

        let disabledDir = getDisabledDirectory(for: app.id)
        let persistentPluginURL = disabledDir.appendingPathComponent(pluginName)
        if FileManager.default.fileExists(atPath: persistentPluginURL.path) {
            try injector.cmdRemove(persistentPluginURL, recursively: true)
        }

        let frameworksURL = try injector.locateFrameworksDirectoryInBundle(app.url)
        let appPluginURL = frameworksURL.appendingPathComponent(pluginName)
        if FileManager.default.fileExists(atPath: appPluginURL.path) {
            try injector.eject([appPluginURL])
        }
    }
}
