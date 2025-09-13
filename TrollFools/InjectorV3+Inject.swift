//
//  InjectorV3+Inject.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation

fileprivate var gCachedLibraryIndex: [String: InjectorV3.LibraryModuleEntry] = [:]
fileprivate var gPreparedLibraryURLs: [ObjectIdentifier: [String: URL]] = [:]
fileprivate let gLibraryAliasMap: [String: String] = [
    "ellekit": "CydiaSubstrate",
    "ellekit.framework": "CydiaSubstrate",
    "libellekit.dylib": "CydiaSubstrate",
    "libsubstitute.dylib": "CydiaSubstrate",
    "libsubstrate.dylib": "CydiaSubstrate",
    "cydiasubstrate": "CydiaSubstrate",
    "cydiasubstrate.framework": "CydiaSubstrate",
]

extension InjectorV3 {
    enum Strategy: String, CaseIterable {
        case lexicographic
        case fast
        case preorder
        case postorder

        var localizedDescription: String {
            switch self {
            case .lexicographic: NSLocalizedString("Lexicographic", comment: "")
            case .fast: NSLocalizedString("Fast", comment: "")
            case .preorder: NSLocalizedString("Pre-order", comment: "")
            case .postorder: NSLocalizedString("Post-order", comment: "")
            }
        }
    }

    // MARK: - Instance Methods

    func inject(_ assetURLs: [URL], shouldPersist: Bool) throws {
        let preparedAssetURLs = try preprocessAssets(assetURLs)

        precondition(!preparedAssetURLs.isEmpty, "No asset to inject.")
        terminateApp()

        try injectBundles(preparedAssetURLs
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try injectDylibsAndFrameworks(preparedAssetURLs
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" })

        if shouldPersist {
            try persist(preparedAssetURLs)
        }
    }

    // MARK: - Private Methods

    fileprivate func injectBundles(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        for assetURL in assetURLs {
            let targetURL = bundleURL.appendingPathComponent(assetURL.lastPathComponent)

            try cmdCopy(from: assetURL, to: targetURL, clone: true, overwrite: true)
            try cmdChangeOwnerToInstalld(targetURL, recursively: true)
        }
    }

    fileprivate func injectDylibsAndFrameworks(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        Self.cachedLibraryIndex = [:]
        Self.buildLibraryIndexIfNeeded()

        try assetURLs.forEach {
            try standardizeLoadCommandDylibToLocalLibrary($0)
            try applyCoreTrustBypass($0)
        }

        var allNeededKeys: Set<String> = []
        for assetURL in assetURLs {
            let machO: URL = try checkIsBundle(assetURL) ? locateExecutableInBundle(assetURL) : assetURL
            let dylibs = try loadedDylibsOfMachO(machO)
            for imported in dylibs {
                if let (rawKey, _) = libraryKey(fromImportedPath: imported) {
                    let lowered = rawKey.lowercased()
                    let destKey = Self.libraryAliasMap[lowered] ?? rawKey
                    if Self.cachedLibraryIndex[destKey.lowercased()] != nil {
                        allNeededKeys.insert(destKey)
                    }
                }
            }
        }
        let preparedLibs = try prepareLibraryModulesIfNeeded(keys: allNeededKeys)
        guard let targetMachO = try locateAvailableMachO() else {
            DDLogError("All Mach-Os are protected", ddlog: logger)

            throw Error.generic(NSLocalizedString("No eligible framework found.\n\nIt is usually not a bug with TrollFools itself, but rather with the target app. You may re-install that from App Store. You can’t use TrollFools with apps installed via “Asspp” or tweaks like “NoAppThinning”.", comment: ""))
        }

        DDLogInfo("Best matched Mach-O is \(targetMachO.path)", ddlog: logger)

        let resourceURLs: [URL] = preparedLibs + assetURLs
        try makeAlternate(targetMachO)
        do {
            try copyfiles(resourceURLs)
            for assetURL in assetURLs {
                try insertLoadCommandOfAsset(assetURL, to: targetMachO)
            }
            try applyCoreTrustBypass(targetMachO)
        } catch {
            try? restoreAlternate(targetMachO)
            try? batchRemove(resourceURLs)
            throw error
        }
    }

    // MARK: - Core Trust

    fileprivate func applyCoreTrustBypass(_ target: URL) throws {
        let isFramework = checkIsBundle(target)

        let machO: URL
        if isFramework {
            machO = try locateExecutableInBundle(target)
        } else {
            machO = target
        }

        try cmdCoreTrustBypass(machO, teamID: teamID)
        try cmdChangeOwnerToInstalld(target, recursively: isFramework)
    }

    // MARK: - Library Replace

    fileprivate struct LibraryModuleEntry {
        enum Kind { case framework, dylib }
        let kind: Kind
        let key: String
        let zipURL: URL
    }

    fileprivate static var cachedLibraryIndex: [String: LibraryModuleEntry] {
        get { gCachedLibraryIndex }
        set { gCachedLibraryIndex = newValue }
    }
    fileprivate var preparedLibraryURLs: [String: URL] {
        get { gPreparedLibraryURLs[ObjectIdentifier(self)] ?? [:] }
        set { gPreparedLibraryURLs[ObjectIdentifier(self)] = newValue }
    }

    fileprivate static var libraryAliasMap: [String: String] { gLibraryAliasMap }

    fileprivate static func buildLibraryIndexIfNeeded() {
        if !cachedLibraryIndex.isEmpty { return }

        var index: [String: LibraryModuleEntry] = [:]

        let searchRoots: [URL] = [Bundle.main.bundleURL, userLibrariesDirectoryURL]
        for root in searchRoots {
            if root == userLibrariesDirectoryURL {
                // 确保用户库目录存在
                try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            }
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
            for case let fileURL as URL in enumerator {
                guard let isRegular = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular == true else { continue }
                let name = fileURL.lastPathComponent
                if name.hasSuffix(".framework.zip") {
                    let moduleName = String(name.dropLast(".framework.zip".count))
                    // 用户库优先覆盖内置
                    index[moduleName.lowercased()] = LibraryModuleEntry(kind: .framework, key: moduleName, zipURL: fileURL)
                } else if name.hasSuffix(".dylib.zip") {
                    let dylibName = String(name.dropLast(".zip".count))
                    index[dylibName.lowercased()] = LibraryModuleEntry(kind: .dylib, key: dylibName, zipURL: fileURL)
                }
            }
        }

        cachedLibraryIndex = index
    }

    /// 用户自定义库目录：App Support/<bundle-id>/Libraries
    fileprivate static var userLibrariesDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
            .appendingPathComponent("Libraries", isDirectory: true)
    }

    fileprivate func libraryKey(fromImportedPath imported: String) -> (key: String, kind: LibraryModuleEntry.Kind)? {
        let lower = imported.lowercased()
        if let range = lower.range(of: ".framework/") {
            let prefix = lower[..<range.lowerBound]
            if let lastSlash = prefix.lastIndex(of: "/") {
                let start = lower.index(after: lastSlash)
                let name = lower[start..<range.lowerBound]
                return (String(name), .framework)
            } else {
                let name = lower[..<range.lowerBound]
                return (String(name), .framework)
            }
        }
        if let lastSlash = lower.lastIndex(of: "/") {
            let fileName = String(lower[lower.index(after: lastSlash)...])
            if fileName.hasSuffix(".dylib") { return (fileName, .dylib) }
        } else if lower.hasSuffix(".dylib") {
            return (lower, .dylib)
        }
        return nil
    }

    fileprivate func prepareLibraryModulesIfNeeded(keys: Set<String>) throws -> [URL] {
        Self.buildLibraryIndexIfNeeded()
        var prepared: [URL] = []
        for rawKey in keys {
            let key = rawKey.lowercased()
            guard let entry = Self.cachedLibraryIndex[key] else { continue }
            if let existing = preparedLibraryURLs[key] {
                prepared.append(existing)
                continue
            }
            try FileManager.default.unzipItem(at: entry.zipURL, to: temporaryDirectoryURL)
            let targetURL: URL
            switch entry.kind {
            case .framework:
                let fwkURL = temporaryDirectoryURL.appendingPathComponent("\(entry.key).framework")
                targetURL = fwkURL
                try markBundlesAsInjected([fwkURL], privileged: false)
                let macho = fwkURL.appendingPathComponent(entry.key)
                try cmdCoreTrustBypass(macho, teamID: teamID)
                try cmdChangeOwnerToInstalld(fwkURL, recursively: true)
            case .dylib:
                let dylibURL = temporaryDirectoryURL.appendingPathComponent(entry.key)
                targetURL = dylibURL
                try cmdCoreTrustBypass(dylibURL, teamID: teamID)
                try cmdChangeOwnerToInstalld(dylibURL, recursively: false)
            }
            preparedLibraryURLs[key] = targetURL
            prepared.append(targetURL)
        }
        return prepared
    }

    fileprivate func standardizeLoadCommandDylibToLocalLibrary(_ assetURL: URL) throws {
        let machO: URL
        if checkIsBundle(assetURL) {
            machO = try locateExecutableInBundle(assetURL)
        } else {
            machO = assetURL
        }

        let dylibs = try loadedDylibsOfMachO(machO)
        var neededKeys: Set<String> = []
        for imported in dylibs {
            if let (rawKey, _) = libraryKey(fromImportedPath: imported) {
                let lower = rawKey.lowercased()
                let destKey = Self.libraryAliasMap[lower] ?? rawKey
                if Self.cachedLibraryIndex[destKey.lowercased()] != nil {
                    neededKeys.insert(destKey)
                }
            }
        }
        let _ = try prepareLibraryModulesIfNeeded(keys: neededKeys)
        for imported in dylibs {
            guard let (rawKey, _) = libraryKey(fromImportedPath: imported) else { continue }
            let destKey = Self.libraryAliasMap[rawKey.lowercased()] ?? rawKey
            guard let entry = Self.cachedLibraryIndex[destKey.lowercased()] else { continue }
            let newName: String
            switch entry.kind {
            case .framework:
                newName = "@executable_path/Frameworks/\(entry.key).framework/\(entry.key)"
            case .dylib:
                newName = "@executable_path/Frameworks/\(entry.key)"
            }
            try cmdChangeLoadCommandDylib(machO, from: imported, to: newName)
        }
    }

    // MARK: - Load Commands

    func loadCommandNameOfAsset(_ assetURL: URL) throws -> String {
        var name = "@rpath/"

        if checkIsBundle(assetURL) {
            precondition(assetURL.pathExtension == "framework", "Invalid framework: \(assetURL.path)")
            let machO = try locateExecutableInBundle(assetURL)
            name += machO.pathComponents.suffix(2).joined(separator: "/") // @rpath/XXX.framework/XXX
            precondition(name.contains(".framework/"), "Invalid framework name: \(name)")
        } else {
            precondition(assetURL.pathExtension == "dylib", "Invalid dylib: \(assetURL.path)")
            name += assetURL.lastPathComponent
            precondition(name.hasSuffix(".dylib"), "Invalid dylib name: \(name)") // @rpath/XXX.dylib
        }

        return name
    }

    fileprivate func insertLoadCommandOfAsset(_ assetURL: URL, to target: URL) throws {
        let name = try loadCommandNameOfAsset(assetURL)

        try cmdInsertLoadCommandRuntimePath(target, name: "@executable_path/Frameworks")
        try cmdInsertLoadCommandDylib(target, name: name, weak: useWeakReference)
        try standardizeLoadCommandDylib(target, to: name)
    }

    fileprivate func standardizeLoadCommandDylib(_ target: URL, to name: String) throws {
        precondition(name.hasPrefix("@rpath/"), "Invalid dylib name: \(name)")

        let itemName = String(name[name.index(name.startIndex, offsetBy: 7)...])
        let dylibs = try loadedDylibsOfMachO(target)

        for dylib in dylibs {
            if dylib.hasSuffix("/" + itemName) {
                try cmdChangeLoadCommandDylib(target, from: dylib, to: name)
            }
        }
    }

    // MARK: - Path Clone

    fileprivate func copyfiles(_ assetURLs: [URL]) throws {
        let targetURLs = assetURLs.map {
            frameworksDirectoryURL.appendingPathComponent($0.lastPathComponent)
        }

        for (assetURL, targetURL) in zip(assetURLs, targetURLs) {
            try cmdCopy(from: assetURL, to: targetURL, clone: true, overwrite: true)
            try cmdChangeOwnerToInstalld(targetURL, recursively: checkIsDirectory(assetURL))
        }
    }

    fileprivate func batchRemove(_ assetURLs: [URL]) throws {
        try assetURLs.forEach {
            try cmdRemove($0, recursively: checkIsDirectory($0))
        }
    }

    // MARK: - Path Finder

    fileprivate func locateAvailableMachO() throws -> URL? {
        try frameworkMachOsInBundle(bundleURL)
            .first { try !isProtectedMachO($0) }
    }

    fileprivate static func findResource(_ name: String, fileExtension: String) -> URL {
        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        if let firstArg = ProcessInfo.processInfo.arguments.first {
            let execURL = URL(fileURLWithPath: firstArg)
                .deletingLastPathComponent()
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)
            if FileManager.default.isReadableFile(atPath: execURL.path) {
                return execURL
            }
        }
        if let tfProxy = LSApplicationProxy(forIdentifier: Constants.gAppIdentifier),
           let tfBundleURL = tfProxy.bundleURL()
        {
            let execURL = tfBundleURL
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)
            if FileManager.default.isReadableFile(atPath: execURL.path) {
                return execURL
            }
        }
        fatalError("Unable to locate resource \(name)")
    }
}
