//
//  InjectorV3+Preprocess.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import ArArchiveKit
import CocoaLumberjackSwift
import Foundation
import SWCompression
import ZIPFoundation

extension InjectorV3 {
    // MARK: - Constants

    fileprivate static let allowedPathExtensions: Set<String> = ["bundle", "dylib", "framework"]

    // MARK: - Shared Methods

    func preprocessAssets(_ assetURLs: [URL]) throws -> [URL] {
        DDLogVerbose("Preprocess \(assetURLs.map { $0.path })", ddlog: logger)

        var preparedAssetURLs = [URL]()
        var urlsToMarkAsInjected = [URL]()

        for assetURL in assetURLs {
            let lowerExt = assetURL.pathExtension.lowercased()
            if lowerExt == "zip" || lowerExt == "deb" {
                let extractedURL = temporaryDirectoryURL
                    .appendingPathComponent("\(UUID().uuidString)_\(assetURL.lastPathComponent)")
                    .appendingPathExtension("extracted")

                try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
                if lowerExt == "zip" {
                    try FileManager.default.unzipItem(at: assetURL, to: extractedURL)
                } else {
                    try extractDebianPackage(at: assetURL, to: extractedURL)
                }

                var extractedItems = [URL]()
                if let enumerator = FileManager.default.enumerator(
                    at: extractedURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    while let item = enumerator.nextObject() as? URL {
                        let itemExt = item.pathExtension.lowercased()
                        guard Self.allowedPathExtensions.contains(itemExt) else {
                            continue
                        }
                        extractedItems.append(item)
                        if itemExt == "bundle" || itemExt == "framework" {
                            enumerator.skipDescendants()
                            continue
                        }
                    }
                }

                for extractedItem in extractedItems {
                    if checkIsBundle(extractedItem) {
                        urlsToMarkAsInjected.append(extractedItem)
                    }
                }

                preparedAssetURLs.append(contentsOf: extractedItems)
                continue
            } else if Self.allowedPathExtensions.contains(lowerExt) {
                let copiedURL = temporaryDirectoryURL
                    .appendingPathComponent(assetURL.lastPathComponent)
                try FileManager.default.copyItem(at: assetURL, to: copiedURL)

                if checkIsBundle(copiedURL) {
                    urlsToMarkAsInjected.append(copiedURL)
                }

                preparedAssetURLs.append(copiedURL)
                continue
            }
        }

        try markBundlesAsInjected(urlsToMarkAsInjected, privileged: false)

        preparedAssetURLs.removeAll(where: { Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent.lowercased()) })
        guard !preparedAssetURLs.isEmpty else {
            throw Error.generic(NSLocalizedString("No valid plug-ins found.", comment: ""))
        }

        return preparedAssetURLs
    }
}

fileprivate extension InjectorV3 {
    func extractDebianPackage(at debURL: URL, to targetURL: URL) throws {
        let fileHandle = try FileHandle(forReadingFrom: debURL)
        defer {
            try? fileHandle.close()
        }

        let archiveData = fileHandle.readDataToEndOfFile()
        let archiveReader = try ArArchiveReader(archive: [UInt8](archiveData))

        var contentData: Data?
        for (header, data) in archiveReader {
            if header.name == "data.tar.gz" {
                DDLogInfo("Extracting \(header.name)", ddlog: logger)
                contentData = try GzipArchive.unarchive(archive: Data(data))
                break
            } else if header.name == "data.tar.bz2" {
                DDLogInfo("Extracting \(header.name)", ddlog: logger)
                contentData = try BZip2.decompress(data: Data(data))
                break
            } else if header.name == "data.tar.lzma" {
                DDLogInfo("Extracting \(header.name)", ddlog: logger)
                contentData = try LZMA.decompress(data: Data(data))
                break
            } else if header.name == "data.tar.xz" {
                DDLogInfo("Extracting \(header.name)", ddlog: logger)
                contentData = try XZArchive.unarchive(archive: Data(data))
                break
            } else if header.name == "data.tar.lz4" {
                DDLogInfo("Extracting \(header.name)", ddlog: logger)
                contentData = try LZ4.decompress(data: Data(data))
                break
            } else {
                continue
            }
        }

        guard let contentData else {
            throw Error.generic(NSLocalizedString("Unable to locate the data archive in the Debian package.", comment: ""))
        }

        let tarURL = targetURL.appendingPathComponent("data.tar")
        try contentData.write(to: tarURL)

        let tarHandle = try FileHandle(forReadingFrom: tarURL)
        defer {
            try? tarHandle.close()
        }

        var hasAnyDylib = false
        var tarReader = TarReader(fileHandle: tarHandle)
        while let entry = try tarReader.read() {
            guard entry.info.type == .regular,
                  entry.info.name.hasSuffix(".dylib"),
                  let entryData = entry.data
            else {
                continue
            }

            let dylibName = URL(fileURLWithPath: entry.info.name, relativeTo: targetURL).lastPathComponent
            guard !dylibName.hasPrefix(".") else {
                continue
            }

            DDLogWarn("Found dylib \(entry.info.name) name \(dylibName)", ddlog: logger)

            let entryURL = targetURL.appendingPathComponent(dylibName)
            try entryData.write(to: entryURL)
            hasAnyDylib = true
        }

        if !hasAnyDylib {
            throw Error.generic(NSLocalizedString("No dylib found in the Debian package.", comment: ""))
        }
    }
}
