//
//  InjectorV3+Eject.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation

extension InjectorV3 {
    // MARK: - Instance Methods

    func ejectAll(shouldDesist: Bool) throws {
        var assetURLs: [URL]

        assetURLs = injectedAssetURLsInBundle(bundleURL)
        if !assetURLs.isEmpty {
            try eject(assetURLs, shouldDesist: shouldDesist)
        }

        if shouldDesist {
            assetURLs = persistedAssetURLs(bid: appID)
            if !assetURLs.isEmpty {
                desist(assetURLs)
            }
        }
    }

    func eject(_ assetURLs: [URL], shouldDesist: Bool) throws {
        precondition(!assetURLs.isEmpty, "No asset to eject.")
        terminateApp()

        if shouldDesist {
            desist(assetURLs)
        } else {
            persistIfNecessary(assetURLs)
        }

        try ejectBundles(assetURLs
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try ejectDylibsAndFrameworks(assetURLs
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" })
    }

    // MARK: - Private Methods

    fileprivate func ejectBundles(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        for assetURL in assetURLs {
            guard checkIsInjectedBundle(assetURL) else {
                continue
            }

            try? cmdRemove(assetURL, recursively: true)
        }
    }

    fileprivate func ejectDylibsAndFrameworks(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        let targetURLs = try collectModifiedMachOs()
        guard !targetURLs.isEmpty else {
            DDLogError("Unable to find any modified Mach-Os", ddlog: logger)
            throw Error.generic(NSLocalizedString("No eligible framework found.", comment: ""))
        }

        DDLogInfo("Modified Mach-Os \(targetURLs.map { $0.path })", ddlog: logger)

        for assetURL in assetURLs {
            try targetURLs.forEach {
                try removeLoadCommandOfAsset(assetURL, from: $0)
            }
            try? cmdRemove(assetURL, recursively: checkIsDirectory(assetURL))
        }

        try targetURLs.forEach {
            try cmdCoreTrustBypass($0, teamID: teamID)
            try cmdChangeOwnerToInstalld($0)
        }

        if !hasInjectedAsset {
            try targetURLs.forEach { try restoreAlternate($0) }

            let substrateFwkURL = bundleURL.appendingPathComponent("Frameworks/\(Self.substrateFwkName)", isDirectory: true)
            try? cmdRemove(substrateFwkURL, recursively: true)
        }
    }

    fileprivate func collectModifiedMachOs() throws -> [URL] {
        try frameworkMachOsInBundle(bundleURL)
            .filter { hasAlternate($0) }.elements
    }

    // MARK: - Load Commands

    fileprivate func removeLoadCommandOfAsset(_ assetURL: URL, from target: URL) throws {
        let name = try loadCommandNameOfAsset(assetURL)
        try cmdRemoveLoadCommandDylib(target, name: name)
    }
}
