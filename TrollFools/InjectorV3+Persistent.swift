//
//  InjectorV3+Persistent.swift
//  TrollFools
//
//  Created by Rachel on 10/9/2025.
//

import Foundation

extension InjectorV3 {
    func persist(_ assetURLs: [URL]) throws {
        for filteredURL in filteredURLs(assetURLs) {
            let destURL = persistentPlugInsDirectoryURL.appendingPathComponent(filteredURL.lastPathComponent)
            try cmdCopy(from: filteredURL, to: destURL, overwrite: true)
            try cmdChangeOwner(destURL, owner: 501, groupOwner: 501, recursively: checkIsDirectory(destURL))
        }
    }

    func persistIfNecessary(_ assetURLs: [URL]) {
        var urlsToPersist = [URL]()
        let fileManager = FileManager.default
        for filteredURL in filteredURLs(assetURLs) {
            let destURL = persistentPlugInsDirectoryURL.appendingPathComponent(filteredURL.lastPathComponent)
            if !fileManager.fileExists(atPath: destURL.path) {
                urlsToPersist.append(filteredURL)
            }
        }
        try? persist(urlsToPersist)
    }

    func desist(_ assetURLs: [URL]) {
        for filteredURL in filteredURLs(assetURLs) {
            let destURL = persistentPlugInsDirectoryURL.appendingPathComponent(filteredURL.lastPathComponent)
            try? cmdRemove(destURL, recursively: checkIsDirectory(destURL))
        }
    }

    func persistedAssetURLs(bid: String) -> [URL] {
        let base = Self.persistentPlugInsRootURL.appendingPathComponent(bid, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: base.path) else {
            return []
        }
        return filteredURLs(contents
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { base.appendingPathComponent($0) })
    }

    func hasPersistedAssets(bid: String) -> Bool {
        let base = Self.persistentPlugInsRootURL.appendingPathComponent(bid, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: base.path) else {
            return false
        }
        return !filteredURLs(contents.map { base.appendingPathComponent($0) }).isEmpty
    }

    fileprivate func filteredURLs(_ assetURLs: [URL]) -> [URL] {
        assetURLs.filter {
            $0.pathExtension.lowercased() == "bundle" ||
                $0.pathExtension.lowercased() == "dylib" ||
                $0.pathExtension.lowercased() == "framework"
        }
    }
}
