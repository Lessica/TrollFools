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
        }
    }

    func desist(_ assetURLs: [URL]) throws {
        for filteredURL in filteredURLs(assetURLs) {
            let destURL = persistentPlugInsDirectoryURL.appendingPathComponent(filteredURL.lastPathComponent)
            try? cmdRemove(destURL, recursively: checkIsDirectory(destURL))
        }
    }

    fileprivate func filteredURLs(_ assetURLs: [URL]) -> [URL] {
        assetURLs.filter {
            $0.pathExtension.lowercased() == "bundle" ||
                $0.pathExtension.lowercased() == "dylib" ||
                $0.pathExtension.lowercased() == "framework"
        }
    }
}
