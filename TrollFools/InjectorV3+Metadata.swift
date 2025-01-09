//
//  InjectorV3+Metadata.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import Foundation

extension InjectorV3 {

    fileprivate static let metadataPlistName = "iTunesMetadata.plist"
    fileprivate static let metadataPlistBackupName = "\(metadataPlistName).bak"

    // MARK: - Instance Methods

    var isMetadataDetached: Bool { isMetadataDetachedInBundle(bundleURL) }

    func setMetadataDetached(_ detached: Bool) throws {
        let containerURL = bundleURL.deletingLastPathComponent()

        let metaURL = containerURL.appendingPathComponent(Self.metadataPlistName)
        let metaBackupURL = containerURL.appendingPathComponent(Self.metadataPlistBackupName)

        if detached && !isMetadataDetached {
            try? cmdMove(from: metaURL, to: metaBackupURL, overwrite: false)
        }

        if !detached && isMetadataDetached {
            try? cmdMove(from: metaBackupURL, to: metaURL, overwrite: false)
        }
    }

    // MARK: - Shared Methods

    func isMetadataDetachedInBundle(_ target: URL) -> Bool {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        let containerURL = target.deletingLastPathComponent()
        let metaBackupURL = containerURL.appendingPathComponent(Self.metadataPlistBackupName)

        return FileManager.default.fileExists(atPath: metaBackupURL.path)
    }

    func isAllowedToAttachOrDetachMetadataInBundle(_ target: URL) -> Bool {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        let containerURL = target.deletingLastPathComponent()

        let metaURL = containerURL.appendingPathComponent(Self.metadataPlistName)
        let metaBackupURL = containerURL.appendingPathComponent(Self.metadataPlistBackupName)

        return FileManager.default.fileExists(atPath: metaURL.path) || FileManager.default.fileExists(atPath: metaBackupURL.path)
    }
}
