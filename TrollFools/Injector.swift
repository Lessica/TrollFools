//
//  Injector.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import MachOKit
import SwiftUI
import ZIPFoundation

final class Injector {

    private static let markerName = ".troll-fools"

    static func isBundleEligible(_ target: URL) -> Bool {
        let frameworksURL = target.appendingPathComponent("Frameworks")
        return !((try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil).isEmpty) ?? true)
    }

    static func isBundleInjected(_ target: URL) -> Bool {
        let frameworksURL = target.appendingPathComponent("Frameworks")
        let substrateFwkURL = frameworksURL.appendingPathComponent("CydiaSubstrate.framework")
        return FileManager.default.fileExists(atPath: substrateFwkURL.path)
    }

    static func injectedPlugInURLs(_ target: URL) -> [URL] {
        return (_injectedBundleURLs(target) + _injectedDylibAndFrameworkURLs(target))
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    static func isBundleDetached(_ target: URL) -> Bool {
        let containerURL = target.deletingLastPathComponent()
        let metaBackupURL = containerURL.appendingPathComponent("iTunesMetadata.plist.bak")
        return FileManager.default.fileExists(atPath: metaBackupURL.path)
    }

    static func isBundleAllowedToAttachOrDetach(_ target: URL) -> Bool {
        let containerURL = target.deletingLastPathComponent()

        let metaURL = containerURL.appendingPathComponent("iTunesMetadata.plist")
        let metaBackupURL = containerURL.appendingPathComponent("iTunesMetadata.plist.bak")

        return FileManager.default.fileExists(atPath: metaURL.path) || FileManager.default.fileExists(atPath: metaBackupURL.path)
    }

    lazy var isDetached: Bool = Self.isBundleDetached(bundleURL)

    func setDetached(_ detached: Bool) throws {
        let containerURL = bundleURL.deletingLastPathComponent()

        let metaURL = containerURL.appendingPathComponent("iTunesMetadata.plist")
        let metaBackupURL = containerURL.appendingPathComponent("iTunesMetadata.plist.bak")

        if detached && !isDetached {
            try? moveURL(metaURL, to: metaBackupURL, shouldOverride: false)
        }

        if !detached && isDetached {
            try? moveURL(metaBackupURL, to: metaURL, shouldOverride: false)
        }
    }

    private static func _injectedBundleURLs(_ target: URL) -> [URL] {
        guard let bundleContentURLs = try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        let bundleURLs = bundleContentURLs
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
            .filter { $0.pathExtension.lowercased() == "bundle" }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(markerName).path) }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        return bundleURLs
    }

    private static func _injectedDylibAndFrameworkURLs(_ target: URL) -> [URL] {
        let frameworksURL = target.appendingPathComponent("Frameworks")
        guard let frameworksContentURLs = try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil) else {
            return []
        }

        let dylibURLs = frameworksContentURLs
            .filter { $0.pathExtension.lowercased() == "dylib" && !$0.lastPathComponent.hasPrefix("libswift") }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        let frameworkURLs = frameworksContentURLs
            .filter { $0.lastPathComponent != "CydiaSubstrate.framework" && $0.pathExtension.lowercased() == "framework" }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(markerName).path) }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        return dylibURLs + frameworkURLs
    }

    private static func isBundleOrFrameworkURL(_ url: URL) -> Bool {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let pathExt = url.pathExtension.lowercased()
        return isDirectory && (pathExt == "app" || pathExt == "framework")
    }

    private let bundleURL: URL
    private let tempURL: URL
    private var teamID: String

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool

    private lazy var infoPlistURL: URL = bundleURL.appendingPathComponent("Info.plist")
    private lazy var mainExecutableURL: URL = {
        let infoPlist = NSDictionary(contentsOf: infoPlistURL)!
        let mainExecutable = infoPlist["CFBundleExecutable"] as! String
        return bundleURL.appendingPathComponent(mainExecutable)
    }()

    private lazy var frameworksURL: URL = {
        let fwkURL = bundleURL.appendingPathComponent("Frameworks")
        if !FileManager.default.fileExists(atPath: fwkURL.path) {
            try? makeDirectory(fwkURL)
        }
        return fwkURL
    }()

    private var hasInjectedPlugIn: Bool {
        !Self.injectedPlugInURLs(bundleURL).isEmpty
    }

    private init() { fatalError("Not implemented") }

    init(_ bundleURL: URL, appID: String, teamID: String) throws {
        self.bundleURL = bundleURL
        self.teamID = teamID
        self.tempURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
            create: true
        )
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(appID)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(appID)")
        try updateTeamIdentifier(bundleURL)
    }

    private func updateTeamIdentifier(_ target: URL) throws {
        let mainURL = try findMainMachO(target)
        let targetFile = try MachOKit.loadFromFile(url: mainURL)
        switch targetFile {
        case .machO(let machOFile):
            if let codeSign = machOFile.codeSign,
               let teamID = codeSign.codeDirectory?.teamId(in: codeSign)
            {
                self.teamID = teamID
            }
        case .fat(let fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                if let codeSign = machOFile.codeSign,
                   let teamID = codeSign.codeDirectory?.teamId(in: codeSign)
                {
                    self.teamID = teamID
                    break
                }
            }
        }
    }

    private lazy var substrateZipURL: URL = Bundle.main.url(forResource: "CydiaSubstrate.framework", withExtension: "zip")!
    private lazy var substrateFwkURL: URL = tempURL.appendingPathComponent("CydiaSubstrate.framework")
    private lazy var substrateMainMachOURL: URL = substrateFwkURL.appendingPathComponent("CydiaSubstrate")
    private lazy var targetSubstrateFwkURL: URL = frameworksURL.appendingPathComponent("CydiaSubstrate.framework")
    private lazy var targetSubstrateMainMachOURL: URL = targetSubstrateFwkURL.appendingPathComponent("CydiaSubstrate")

    private func isMachOURL(_ url: URL) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer {
            fileHandle.closeFile()
        }
        let magicData = fileHandle.readData(ofLength: 4)
        guard magicData.count == 4 else {
            return false
        }
        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == 0xfeedface || magic == 0xfeedfacf
    }

    private func frameworkMachOURLs(_ target: URL) throws -> [URL] {
        let dylibs = try loadedDylibs(target)

        let rpath = URL(fileURLWithPath: target.deletingLastPathComponent().path)
            .appendingPathComponent("Frameworks")

        let initialDylibs = dylibs
            .filter { $0.hasPrefix("@rpath/") && $0.contains(".framework/") }
            .map { $0.replacingOccurrences(of: "@rpath", with: rpath.path) }
            .map { URL(fileURLWithPath: $0) }

        var executableURLs = Set<URL>()
        if let enumerator = FileManager.default.enumerator(
            at: frameworksURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let fileAttributes = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]) else {
                    continue
                }

                if (fileAttributes.isDirectory ?? false) && fileURL.pathExtension.lowercased() == "framework" {
                    let markerURL = fileURL.appendingPathComponent(Self.markerName)
                    if FileManager.default.fileExists(atPath: markerURL.path) {
                        enumerator.skipDescendants()
                        continue
                    }
                }

                guard fileAttributes.isRegularFile ?? false else {
                    continue
                }

                executableURLs.insert(fileURL)
            }
        }

        var fwkURLs = executableURLs
            .intersection(initialDylibs)
            .filter { isMachOURL($0) }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        if preferMainExecutable {
            fwkURLs.insert(target, at: 0)
        } else {
            fwkURLs.append(target)
        }

        return fwkURLs
    }

    private func copyTempInjectURLs(_ injectURLs: [URL]) throws -> [URL] {
        let tempURLs = injectURLs.map { tempURL.appendingPathComponent($0.lastPathComponent) }
        for (injectURL, tempURL) in zip(injectURLs, tempURLs) {
            try FileManager.default.copyItem(at: injectURL, to: tempURL)
        }
        return tempURLs
    }

    private func markInjectDirectories(_ injectURLs: [URL], withRootPermission: Bool) throws {
        let filteredURLs = injectURLs
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }

        if withRootPermission {
            let markerURL = tempURL.appendingPathComponent(Self.markerName)
            try Data().write(to: markerURL, options: .atomic)
            try changeOwnerToInstalld(markerURL, isDirectory: false)

            try filteredURLs.forEach {
                try copyURL(markerURL, to: $0.appendingPathComponent(Self.markerName))
            }
        } else {
            try filteredURLs.forEach {
                try Data().write(to: $0.appendingPathComponent(Self.markerName), options: .atomic)
            }
        }
    }

    private func throwCommandFailure(_ command: String, reason: AuxiliaryExecute.TerminationReason) throws -> Never {
        switch reason {
        case .exit(let code):
            throw NSError(domain: kTrollFoolsErrorDomain, code: 1, userInfo: [
                NSLocalizedDescriptionKey: String(format: NSLocalizedString("%@ exited with code %d", comment: ""), command, code),
            ])
        case .uncaughtSignal(let signal):
            throw NSError(domain: kTrollFoolsErrorDomain, code: 1, userInfo: [
                NSLocalizedDescriptionKey: String(format: NSLocalizedString("%@ terminated with signal %d", comment: ""), command, signal),
            ])
        }
    }

    private func removeURL(_ target: URL, isDirectory: Bool) throws {
        let retCode = try Execute.rootSpawn(binary: rmBinaryURL.path, arguments: [
            isDirectory ? "-rf" : "-f", target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("rm", reason: retCode)
        }

        NSLog("rm \(target.lastPathComponent) done")
    }

    private func _changeOwner(_ target: URL, owner: String, isDirectory: Bool) throws {
        var args = [
            String(format: "%@:%@", owner, owner), target.path,
        ]
        if isDirectory {
            args.insert("-R", at: 0)
        }

        let retCode = try Execute.rootSpawn(binary: chownBinaryURL.path, arguments: args)
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("chown", reason: retCode)
        }

        NSLog("chown \(target.lastPathComponent) done")
    }

    private func changeOwnerToInstalld(_ target: URL, isDirectory: Bool) throws {
        try _changeOwner(target, owner: "33", isDirectory: isDirectory) // _installd
    }

    private func copyURL(_ src: URL, to dst: URL) throws {
        try? removeURL(dst, isDirectory: true)

        let retCode = try Execute.rootSpawn(binary: cpBinaryURL.path, arguments: [
            "-rfp", src.path, dst.path,
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("cp", reason: retCode)
        }

        NSLog("cp \(src.lastPathComponent) to \(dst.lastPathComponent) done")
    }

    private func moveURL(_ src: URL, to dst: URL, shouldOverride: Bool = false) throws {
        if shouldOverride {
            try? removeURL(dst, isDirectory: true)
        }

        var args = [
            src.path, dst.path,
        ]

        if shouldOverride {
            args.insert("-f", at: 0)
        }

        let retCode = try Execute.rootSpawn(binary: mvBinaryURL.path, arguments: args)
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("mv", reason: retCode)
        }

        NSLog("mv \(src.lastPathComponent) to \(dst.lastPathComponent) done")
    }

    private func makeDirectory(_ target: URL) throws {
        let retCode = try Execute.rootSpawn(binary: mkdirBinaryURL.path, arguments: [
            "-p", target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("mkdir", reason: retCode)
        }

        NSLog("mkdir \(target.lastPathComponent) done")
    }

    @discardableResult
    private func copyTargetInjectURLs(_ injectURLs: [URL]) throws -> [URL] {
        let targetURLs = injectURLs.map { frameworksURL.appendingPathComponent($0.lastPathComponent) }
        for (injectURL, targetURL) in zip(injectURLs, targetURLs) {
            try copyURL(injectURL, to: targetURL)
        }
        return targetURLs
    }

    private lazy var cpBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            Bundle.main.url(forResource: "cp", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "cp-15", withExtension: nil)!
        }
    }()
    
    private lazy var composeBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            Bundle.main.url(forResource: "composedeb", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "composedeb-15", withExtension: nil)!
        }
    }()

    private lazy var chownBinaryURL: URL = Bundle.main.url(forResource: "chown", withExtension: nil)!
    private lazy var ctBypassBinaryURL: URL = Bundle.main.url(forResource: "ct_bypass", withExtension: nil)!
    private lazy var insertDylibBinaryURL: URL = Bundle.main.url(forResource: "insert_dylib", withExtension: nil)!
    private lazy var installNameToolBinaryURL: URL = Bundle.main.url(forResource: "install_name_tool", withExtension: nil)!

    private lazy var ldidBinaryURL: URL = {
        if #available(iOS 15.0, *) {
            Bundle.main.url(forResource: "ldid", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "ldid-14", withExtension: nil)!
        }
    }()

    private lazy var mkdirBinaryURL: URL = Bundle.main.url(forResource: "mkdir", withExtension: nil)!

    private lazy var mvBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            Bundle.main.url(forResource: "mv", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "mv-15", withExtension: nil)!
        }
    }()

    private lazy var optoolBinaryURL: URL = Bundle.main.url(forResource: "optool", withExtension: nil)!
    private lazy var rmBinaryURL: URL = Bundle.main.url(forResource: "rm", withExtension: nil)!

    private func backup(_ url: URL) throws {
        let backupURL = url.appendingPathExtension("troll-fools.bak")
        guard !FileManager.default.fileExists(atPath: backupURL.path) else {
            return
        }
        try copyURL(url, to: backupURL)
    }

    private func restoreIfExists(_ url: URL) throws {
        let backupURL = url.appendingPathExtension("troll-fools.bak")
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return
        }

        try? removeURL(url, isDirectory: false)

        try copyURL(backupURL, to: url)
        try changeOwnerToInstalld(url, isDirectory: false)

        try? removeURL(backupURL, isDirectory: false)
    }

    private func fakeSignIfNecessary(_ url: URL, force: Bool = false) throws {
        var hasCodeSign = false
        var isExecutable = false

        let target = try findMainMachO(url)
        let targetFile = try MachOKit.loadFromFile(url: target)
        switch targetFile {
        case .machO(let machOFile):
            isExecutable = machOFile.header.fileType == .execute
            for command in machOFile.loadCommands {
                switch command {
                case .codeSignature(_):
                    hasCodeSign = true
                    break
                default:
                    continue
                }
            }
        case .fat(let fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                isExecutable = machOFile.header.fileType == .execute
                for command in machOFile.loadCommands {
                    switch command {
                    case .codeSignature(_):
                        hasCodeSign = true
                        break
                    default:
                        continue
                    }
                }
            }
        }

        guard force || !hasCodeSign else {
            return
        }

        if isExecutable {
            var receipt: AuxiliaryExecute.ExecuteReceipt

            receipt = try Execute.rootSpawnWithOutputs(binary: ldidBinaryURL.path, arguments: [
                "-e", url.path,
            ])

            guard case .exit(let code) = receipt.terminationReason, code == 0 else {
                try throwCommandFailure("ldid", reason: receipt.terminationReason)
            }

            let xmlContent = receipt.stdout
            let xmlURL = tempURL
                .appendingPathComponent(url.lastPathComponent)
                .appendingPathExtension("xml")
            try xmlContent.write(to: xmlURL, atomically: true, encoding: .utf8)

            receipt = try Execute.rootSpawnWithOutputs(binary: ldidBinaryURL.path, arguments: [
                "-S\(xmlURL.path)", url.path,
            ])

            guard case .exit(let code) = receipt.terminationReason, code == 0 else {
                try throwCommandFailure("ldid", reason: receipt.terminationReason)
            }
        } else {
            let retCode = try Execute.rootSpawn(binary: ldidBinaryURL.path, arguments: [
                "-S", url.path,
            ])
            guard case .exit(let code) = retCode, code == 0 else {
                try throwCommandFailure("ldid", reason: retCode)
            }
        }

        NSLog("ldid \(url.lastPathComponent) done")
    }

    private func ctBypass(_ url: URL) throws {
        try fakeSignIfNecessary(url)

        let target = try findMainMachO(url)
        let retCode = try Execute.rootSpawn(binary: ctBypassBinaryURL.path, arguments: [
            "-i", target.path, "-t", teamID, "-r",
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("ct_bypass", reason: retCode)
        }

        NSLog("ct_bypass \(url.lastPathComponent) done")
    }

    private func runtimePaths(_ target: URL) throws -> Set<String> {
        var paths = Set<String>()
        let file = try MachOKit.loadFromFile(url: target)
        switch file {
        case .machO(let machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case .rpath(let rpathCommand):
                    paths.insert(rpathCommand.path(in: machOFile))
                default:
                    continue
                }
            }
        case .fat(let fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case .rpath(let rpathCommand):
                        paths.insert(rpathCommand.path(in: machOFile))
                    default:
                        continue
                    }
                }
            }
        }
        return paths
    }

    private func loadedDylibs(_ target: URL) throws -> Set<String> {
        var dylibs = Set<String>()
        let file = try MachOKit.loadFromFile(url: target)
        switch file {
        case .machO(let machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case .loadDylib(let loadDylibCommand):
                    dylibs.insert(loadDylibCommand.dylib(in: machOFile).name)
                case .loadWeakDylib(let loadWeakDylibCommand):
                    dylibs.insert(loadWeakDylibCommand.dylib(in: machOFile).name)
                default:
                    continue
                }
            }
        case .fat(let fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case .loadDylib(let loadDylibCommand):
                        dylibs.insert(loadDylibCommand.dylib(in: machOFile).name)
                    case .loadWeakDylib(let loadWeakDylibCommand):
                        dylibs.insert(loadWeakDylibCommand.dylib(in: machOFile).name)
                    default:
                        continue
                    }
                }
            }
        }
        return dylibs
    }

    private func insertLoadCommand(_ target: URL, url: URL) throws {
        let name: String
        let mainURL = try findMainMachO(url)
        if mainURL != url {
            name = mainURL.pathComponents.suffix(2).joined(separator: "/")
        } else {
            name = url.lastPathComponent
        }

        try _insertLoadCommandRpath(target, name: "@executable_path/Frameworks")
        try _insertLoadCommandDylib(target, name: name, isWeak: useWeakReference)
        try applyTargetFixes(target, name: name)
    }

    private func _insertLoadCommandRpath(_ target: URL, name: String) throws {
        let rpaths = try runtimePaths(target)

        if rpaths.contains(name) {
            NSLog("payload \(name) already inserted")
            return
        }

        try fakeSignIfNecessary(target, force: true)

        let retCode = try Execute.rootSpawn(binary: installNameToolBinaryURL.path, arguments: [
            "-add_rpath", name, target.path,
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("install_name_tool", reason: retCode)
        }

        NSLog("install_name_tool \(name) done")
    }

    private func _insertLoadCommandDylib(_ target: URL, name: String, isWeak: Bool) throws {
        let dylibs = try loadedDylibs(target)

        let payload = "@rpath/" + name
        if dylibs.contains(payload) {
            NSLog("payload \(name) already inserted")
            return
        }

        var args = [
            payload, target.path,
            "--inplace", "--overwrite", "--no-strip-codesig", "--all-yes",
        ]

        if isWeak {
            args.append("--weak")
        }

        let retCode = try Execute.rootSpawn(binary: insertDylibBinaryURL.path, arguments: args)
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("insert_dylib", reason: retCode)
        }

        NSLog("insert_dylib \(payload) done")
    }

    private func removeLoadCommand(_ target: URL, url: URL) throws {
        let name: String
        let mainURL = try findMainMachO(url)
        if mainURL != url {
            name = mainURL.pathComponents.suffix(2).joined(separator: "/")
        } else {
            name = url.lastPathComponent
        }

        try _removeLoadCommandDylib(target, name: name)
    }

    private func _removeLoadCommandDylib(_ target: URL, name: String) throws {
        let dylibs = try loadedDylibs(target)

        let payload = "@rpath/" + name
        guard dylibs.contains(payload) else {
            return
        }

        let retCode = try Execute.rootSpawn(binary: optoolBinaryURL.path, arguments: [
            "uninstall", "-p", payload, "-t", target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("optool", reason: retCode)
        }

        NSLog("optool \(target.lastPathComponent) done")
    }

    private func _applyChange(_ target: URL, from src: String, to dst: String) throws {
        try fakeSignIfNecessary(target, force: true)

        let retCode = try Execute.rootSpawn(binary: installNameToolBinaryURL.path, arguments: [
            "-change", src, dst, target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("install-name-tool", reason: retCode)
        }

        NSLog("install-name-tool \(target.lastPathComponent) done")
    }

    private func findMainMachO(_ target: URL) throws -> URL {
        guard Self.isBundleOrFrameworkURL(target) else {
            return target
        }

        let infoPlistURL = target.appendingPathComponent("Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistURL)

        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any]
        else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: String(format: NSLocalizedString("Failed to parse: %@", comment: ""), infoPlistURL.path),
            ])
        }

        guard let executableName = infoPlist["CFBundleExecutable"] as? String else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: String(format: NSLocalizedString("Failed to find entry CFBundleExecutable in: %@", comment: ""), infoPlistURL.path),
            ])
        }

        let executableURL = target.appendingPathComponent(executableName)
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: String(format: NSLocalizedString("Failed to locate main executable: %@", comment: ""), executableURL.path),
            ])
        }

        return executableURL
    }

    private func applySubstrateFixes(_ target: URL) throws {
        let mainURL = try findMainMachO(target)

        let dylibs = try loadedDylibs(mainURL)
        for dylib in dylibs {
            let lowercasedDylib = dylib.lowercased()
            guard (lowercasedDylib.hasSuffix("/cydiasubstrate") ||
                   lowercasedDylib.hasSuffix("/libsubstrate.dylib") ||
                   lowercasedDylib.hasSuffix("/libsubstitute.dylib") ||
                   lowercasedDylib.hasSuffix("/ellekit") ||
                   lowercasedDylib.hasSuffix("/libellekit.dylib"))
            else {
                continue
            }

            try _applyChange(mainURL, from: dylib, to: "@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate")
        }
    }

    private func applyTargetFixes(_ target: URL, name: String) throws {
        let dylibs = try loadedDylibs(target)
        for dylib in dylibs {
            guard dylib.hasSuffix("/" + name) else {
                continue
            }
            try _applyChange(target, from: dylib, to: "@rpath/" + name)
        }
    }

    private static let ignoredDylibAndFrameworkNames: Set<String> = [
        "libsubstrate.dylib",
        "libsubstitute.dylib",
        "libellekit.dylib",
        "CydiaSubstrate.framework",
    ]

    private static let allowedPathExtensions: Set<String> = ["bundle", "dylib", "framework"]

    private func preprocessURLs(_ urls: [URL]) throws -> [URL] {
        var finalURLs: [URL] = []

        for url in urls {
            if url.pathExtension.lowercased() == "zip" {
                let extractedURL = tempURL
                    .appendingPathComponent(url.lastPathComponent)
                    .appendingPathExtension("extracted")

                try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: url, to: extractedURL)

                let extractedContents = try FileManager.default
                    .contentsOfDirectory(at: extractedURL, includingPropertiesForKeys: nil)
                    .filter { Self.allowedPathExtensions.contains($0.pathExtension.lowercased()) }

                finalURLs.append(contentsOf: extractedContents)
            } else if url.pathExtension.lowercased() == "deb" {
                let extractedURL = tempURL
                    .appendingPathComponent(url.lastPathComponent)
                    .appendingPathExtension("extracted")
                try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
                try _ = decomposeDeb(at: url, to: extractedURL)
                
                var dylibFiles = [URL]()
                var bundleFiles = [URL]()
                let fileManager = FileManager.default
                let enumerator = fileManager.enumerator(at: extractedURL, includingPropertiesForKeys: nil)
                while let file = enumerator?.nextObject() as? URL {
                    if file.pathExtension.lowercased() == "dylib" || file.pathExtension.lowercased() == "framework"{
                        dylibFiles.append(file)
                    }
                    if file.pathExtension.lowercased() == "bundle" {
                        bundleFiles.append(file)
                    }
                }
                try _injectBundles(bundleFiles)
                finalURLs.append(contentsOf: dylibFiles)
            } else {
                finalURLs.append(url)
            }
        }

        guard !finalURLs.isEmpty else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("No valid plug-ins found.", comment: ""),
            ])
        }

        return finalURLs
    }
    
    private func decomposeDeb(at sourceURL: URL, to destinationURL: URL) throws -> String {
        let composedebPath = Bundle.main.url(forResource: "composedeb", withExtension: nil)!.path
        let executablePath = (composedebPath as NSString).deletingLastPathComponent
        let environment = [
            "PATH": "\(executablePath):\(ProcessInfo.processInfo.environment["PATH"] ?? "")"
        ]
        
        let logFilePath = destinationURL.appendingPathComponent("decomposeDeb.log").path
        let logFileHandle: FileHandle?
        
        if FileManager.default.fileExists(atPath: logFilePath) {
            logFileHandle = FileHandle(forWritingAtPath: logFilePath)
            logFileHandle?.seekToEndOfFile()
        } else {
            FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil)
            logFileHandle = FileHandle(forWritingAtPath: logFilePath)
        }
        
        guard let logHandle = logFileHandle else {
            throw NSError(domain: "DecomposeDebErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create log file handle"])
        }
        
        func log(_ message: String) {
            if let data = (message + "\n").data(using: .utf8) {
                logHandle.write(data)
            }
        }
        do {
            log("Starting decomposeDeb for file \(sourceURL.lastPathComponent)")
            log("Using composedeb at path \(composedebPath)")
            log("Executable path: \(executablePath)")
            
            let receipt = try Execute.rootSpawnWithOutputs(binary: composeBinaryURL.path, arguments: [
                sourceURL.path,
                destinationURL.path,
                Bundle.main.bundlePath,
            ], environment: environment)
            guard case .exit(let code) = receipt.terminationReason, code == 0 else {
                let errorMessage = "Command failed with reason: \(receipt.terminationReason) and status: \(receipt.terminationReason)"
                log(errorMessage)
                log("Standard Error: \(receipt.stderr)")
                throw NSError(domain: "DecomposeDebErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Command failed: \(receipt.stderr)"])
            }
            
            log("Command Output: \(receipt.stdout)")
            log("Standard Error: \(receipt.stderr)")
            log("Decompose Deb File \(sourceURL.lastPathComponent) done")
            NSLog("Decompose Deb File \(sourceURL.lastPathComponent) done")
            
            return receipt.stdout
        } catch {
            log("Error occurred: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Public Methods

    func inject(_ injectURLs: [URL]) throws {
        let urlsToInject = try preprocessURLs(injectURLs)

        TFUtilKillAll(mainExecutableURL.lastPathComponent, true)

        let shouldBackup = !hasInjectedPlugIn

        try _injectBundles(urlsToInject
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try _injectDylibsAndFrameworks(urlsToInject
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" },
                                       shouldBackup: shouldBackup)
    }

    private func _injectBundles(_ injectURLs: [URL]) throws {
        let newInjectURLs = try copyTempInjectURLs(injectURLs)
        try markInjectDirectories(newInjectURLs, withRootPermission: false)

        for newInjectURL in newInjectURLs {
            let targetURL = bundleURL.appendingPathComponent(newInjectURL.lastPathComponent)
            try copyURL(newInjectURL, to: targetURL)
            try changeOwnerToInstalld(targetURL, isDirectory: true)
        }
    }

    private func _locateAvailableMachO(shouldBackup: Bool) throws -> URL? {
        var targetURL: URL?

        for frameworkMachOURL in try frameworkMachOURLs(mainExecutableURL) {
            do {
                if shouldBackup {
                    try backup(frameworkMachOURL)
                }

                try ctBypass(frameworkMachOURL)
                try changeOwnerToInstalld(frameworkMachOURL, isDirectory: false)

                targetURL = frameworkMachOURL
                break
            } catch {
                try? restoreIfExists(frameworkMachOURL)
                continue
            }
        }

        return targetURL
    }

    private func _injectDylibsAndFrameworks(_ injectURLs: [URL], shouldBackup: Bool) throws {
        try FileManager.default.unzipItem(at: substrateZipURL, to: tempURL)
        try ctBypass(substrateMainMachOURL)
        try changeOwnerToInstalld(substrateMainMachOURL, isDirectory: false)

        let filteredURLs = injectURLs.filter {
            !Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent)
        }

        let newInjectURLs = try copyTempInjectURLs(filteredURLs)
        for newInjectURL in newInjectURLs {
            try applySubstrateFixes(newInjectURL)
            try ctBypass(newInjectURL)
            try changeOwnerToInstalld(newInjectURL, isDirectory: true)
        }

        guard let targetURL = try _locateAvailableMachO(shouldBackup: shouldBackup) else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("No eligible framework found.\n\nIt is usually not a bug with TrollFools itself, but rather with the target app. You may re-install that from App Store. You can’t use TrollFools with apps installed via “Asspp” or tweaks like “NoAppThinning”.", comment: ""),
            ])
        }

        do {
            try markInjectDirectories([substrateFwkURL], withRootPermission: false)
            try copyTargetInjectURLs([substrateFwkURL])
            try changeOwnerToInstalld(targetSubstrateFwkURL, isDirectory: true)

            try markInjectDirectories(newInjectURLs, withRootPermission: true)
            let copiedURLs: [URL] = try copyTargetInjectURLs(newInjectURLs)
            for copiedURL in copiedURLs {
                try insertLoadCommand(targetURL, url: copiedURL)
            }
            try changeOwnerToInstalld(targetURL, isDirectory: false)

            if !copiedURLs.isEmpty {
                try ctBypass(targetURL)
                try changeOwnerToInstalld(targetURL, isDirectory: false)
            }
        } catch {
            try? restoreIfExists(targetURL)
            throw error
        }
    }

    func eject(_ ejectURLs: [URL]) throws {
        TFUtilKillAll(mainExecutableURL.lastPathComponent, true)

        try _ejectBundles(ejectURLs
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try _ejectDylibsAndFrameworks(ejectURLs
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" })
    }

    private func _ejectBundles(_ ejectURLs: [URL]) throws {
        for ejectURL in ejectURLs {
            let markerURL = ejectURL.appendingPathComponent(Self.markerName)
            guard FileManager.default.fileExists(atPath: markerURL.path) else {
                continue
            }
            try? removeURL(ejectURL, isDirectory: true)
        }
    }

    private func _ejectDylibsAndFrameworks(_ ejectURLs: [URL]) throws {
        guard let targetURL = try _locateAvailableMachO(shouldBackup: false) else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("No eligible framework found.", comment: ""),
            ])
        }

        for ejectURL in ejectURLs {
            try removeLoadCommand(targetURL, url: ejectURL)
            try changeOwnerToInstalld(targetURL, isDirectory: false)

            let isFramework = Self.isBundleOrFrameworkURL(ejectURL)
            try? removeURL(ejectURL, isDirectory: isFramework)
        }

        if !ejectURLs.isEmpty {
            try ctBypass(targetURL)
            try changeOwnerToInstalld(targetURL, isDirectory: false)
        }

        if !hasInjectedPlugIn {
            try? removeURL(targetSubstrateFwkURL, isDirectory: true)
            try? restoreIfExists(targetURL)
        }
    }

    func ejectAll() throws {
        try eject(Self.injectedPlugInURLs(bundleURL))
    }

    deinit {
#if !DEBUG
        try? FileManager.default.removeItem(at: tempURL)
#endif
    }
}
