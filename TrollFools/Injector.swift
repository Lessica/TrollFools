//
//  Injector.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import Foundation
import MachOKit
import ZIPFoundation

final class Injector {

    private static let markerName = ".troll-fools"

    static func isEligibleBundle(_ target: URL) -> Bool {
        let frameworksURL = target.appendingPathComponent("Frameworks")
        return !((try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil).isEmpty) ?? true)
    }

    static func isInjectedBundle(_ target: URL) -> Bool {
        let frameworksURL = target.appendingPathComponent("Frameworks")
        let substrateFwkURL = frameworksURL.appendingPathComponent("CydiaSubstrate.framework")
        return FileManager.default.fileExists(atPath: substrateFwkURL.path)
    }

    static func injectedPlugInURLs(_ target: URL) -> [URL] {
        return (_injectedBundleURLs(target) + _injectedDylibAndFrameworkURLs(target))
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
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

    private static func isFrameworkURL(_ url: URL) -> Bool {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDirectory && url.pathExtension.lowercased() == "framework"
    }

    private let bundleURL: URL
    private let teamID: String
    private let tempURL: URL

    private lazy var infoPlistURL: URL = bundleURL.appendingPathComponent("Info.plist")
    private lazy var mainExecutableURL: URL = {
        let infoPlist = NSDictionary(contentsOf: infoPlistURL)!
        let mainExecutable = infoPlist["CFBundleExecutable"] as! String
        return bundleURL.appendingPathComponent(mainExecutable)
    }()

    private lazy var frameworksURL: URL = bundleURL.appendingPathComponent("Frameworks")

    private var hasInjectedPlugIn: Bool {
        !Self.injectedPlugInURLs(bundleURL).isEmpty
    }

    init(bundleURL: URL, teamID: String) throws {
        self.bundleURL = bundleURL
        self.teamID = teamID
        self.tempURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
            create: true
        )
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
            .filter { $0.hasPrefix("@rpath/") }
            .map { $0.replacingOccurrences(of: "@rpath", with: rpath.path) }
            .map { URL(fileURLWithPath: $0) }

        var executableURLs = Set<URL>()
        if let enumerator = FileManager.default.enumerator(
            at: frameworksURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isExecutableKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let fileAttributes = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]) else {
                    continue
                }

                guard fileAttributes.isRegularFile ?? false else {
                    continue
                }

                executableURLs.insert(fileURL)
            }
        }

        return executableURLs
            .intersection(initialDylibs)
            .filter { isMachOURL($0) }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
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

    private func throwCommandFailure(_ command: String, reason: Execute.TerminationReason) throws -> Never {
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
        let retCode = try Execute.spawn(binary: rmBinaryURL.path, arguments: [
            isDirectory ? "-rf" : "-f", target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("rm", reason: retCode)
        }

        DDLogInfo("rm \(target.lastPathComponent) done")
    }

    private func _changeOwner(_ target: URL, owner: String, isDirectory: Bool) throws {
        var args = [
            String(format: "%@:%@", owner, owner), target.path,
        ]
        if isDirectory {
            args.insert("-R", at: 0)
        }

        let retCode = try Execute.spawn(binary: chownBinaryURL.path, arguments: args)
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("chown", reason: retCode)
        }

        DDLogInfo("chown \(target.lastPathComponent) done")
    }

    private func changeOwnerToInstalld(_ target: URL, isDirectory: Bool) throws {
        try _changeOwner(target, owner: "_installd", isDirectory: isDirectory)
    }

    private func copyURL(_ src: URL, to dst: URL) throws {
        try? removeURL(dst, isDirectory: true)

        let retCode = try Execute.spawn(binary: cpBinaryURL.path, arguments: [
            "-rfp", src.path, dst.path,
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("cp", reason: retCode)
        }

        DDLogInfo("cp \(src.lastPathComponent) to \(dst.lastPathComponent) done")
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

    private lazy var chownBinaryURL: URL = Bundle.main.url(forResource: "chown", withExtension: nil)!
    private lazy var ctBypassBinaryURL: URL = Bundle.main.url(forResource: "ct_bypass", withExtension: nil)!
    private lazy var insertDylibBinaryURL: URL = Bundle.main.url(forResource: "insert_dylib", withExtension: nil)!
    private lazy var installNameToolBinaryURL: URL = Bundle.main.url(forResource: "llvm-install-name-tool", withExtension: nil)!
    private lazy var ldidBinaryURL: URL = Bundle.main.url(forResource: "ldid", withExtension: nil)!
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

    private func fakeSignIfNecessary(_ url: URL) throws {
        var hasCodeSign = false

        let target = try findMainMachO(url)
        let targetFile = try MachOKit.loadFromFile(url: target)
        switch targetFile {
        case .machO(let machOFile):
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

        guard !hasCodeSign else {
            return
        }

        let retCode = try Execute.spawn(binary: ldidBinaryURL.path, arguments: [
            "-S", url.path,
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("ldid", reason: retCode)
        }

        DDLogInfo("ldid \(url.lastPathComponent) done")
    }

    private func ctBypass(_ url: URL) throws {
        try fakeSignIfNecessary(url)

        let target = try findMainMachO(url)
        let retCode = try Execute.spawn(binary: ctBypassBinaryURL.path, arguments: [
            "-i", target.path, "-t", teamID, "-r",
        ])
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("ct_bypass", reason: retCode)
        }

        DDLogInfo("ct_bypass \(url.lastPathComponent) done")
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

        try _insertLoadCommandDylib(target, name: name, isWeak: true)
        try applyTargetFixes(target, name: name)
    }

    private func _insertLoadCommandDylib(_ target: URL, name: String, isWeak: Bool) throws {
        let dylibs = try loadedDylibs(target)

        let payload = "@rpath/" + name
        if dylibs.contains(payload) {
            DDLogInfo("payload \(name) already inserted")
            return
        }

        var args = [
            payload, target.path,
            "--inplace", "--overwrite", "--no-strip-codesig", "--all-yes",
        ]

        if isWeak {
            args.append("--weak")
        }

        let retCode = try Execute.spawn(binary: insertDylibBinaryURL.path, arguments: args)
        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("insert_dylib", reason: retCode)
        }

        DDLogInfo("insert_dylib \(payload) done")
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

        let retCode = try Execute.spawn(binary: optoolBinaryURL.path, arguments: [
            "uninstall", "-p", payload, "-t", target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("optool", reason: retCode)
        }

        DDLogInfo("optool \(target.lastPathComponent) done")
    }

    private func _applyChange(_ target: URL, from src: String, to dst: String) throws {
        let retCode = try Execute.spawn(binary: installNameToolBinaryURL.path, arguments: [
            "-change", src, dst, target.path,
        ])

        guard case .exit(let code) = retCode, code == 0 else {
            try throwCommandFailure("llvm-install-name-tool", reason: retCode)
        }

        DDLogInfo("llvm-install-name-tool \(target.lastPathComponent) done")
    }

    private func findMainMachO(_ target: URL) throws -> URL {
        guard Self.isFrameworkURL(target) else {
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

        let dylibs = try loadedDylibs(target)
        for dylib in dylibs {
            guard (dylib.hasSuffix("/CydiaSubstrate") ||
                   dylib.hasSuffix("/libsubstrate.dylib") ||
                   dylib.hasSuffix("/libsubstitute.dylib") ||
                   dylib.hasSuffix("/libellekit.dylib"))
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

    private static let ignoredDylibAndFrameworkNames: [String] = [
        "libsubstrate.dylib",
        "libsubstitute.dylib",
        "libellekit.dylib",
        "CydiaSubstrate.framework",
    ]

    // MARK: - Public Methods

    func inject(_ injectURLs: [URL]) throws {
        TFUtilKillAll(mainExecutableURL.lastPathComponent, true)

        let shouldBackup = !hasInjectedPlugIn

        try _injectBundles(injectURLs
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try _injectDylibsAndFrameworks(injectURLs
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" },
                                       shouldBackup: shouldBackup)
    }

    func _injectBundles(_ injectURLs: [URL]) throws {
        let newInjectURLs = try copyTempInjectURLs(injectURLs)
        try markInjectDirectories(newInjectURLs, withRootPermission: false)

        for newInjectURL in newInjectURLs {
            let targetURL = bundleURL.appendingPathComponent(newInjectURL.lastPathComponent)
            try copyURL(newInjectURL, to: targetURL)
            try changeOwnerToInstalld(targetURL, isDirectory: true)
        }
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

        guard let targetURL else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("No eligible framework found.", comment: ""),
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
        var targetURL: URL?
        for frameworkMachOURL in try frameworkMachOURLs(mainExecutableURL) {
            do {
                try ctBypass(frameworkMachOURL)
                try changeOwnerToInstalld(frameworkMachOURL, isDirectory: false)

                targetURL = frameworkMachOURL
                break
            } catch {
                continue
            }
        }

        guard let targetURL else {
            throw NSError(domain: kTrollFoolsErrorDomain, code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("No eligible framework found.", comment: ""),
            ])
        }

        for ejectURL in ejectURLs {
            try removeLoadCommand(targetURL, url: ejectURL)
            try changeOwnerToInstalld(targetURL, isDirectory: false)

            let isFramework = Self.isFrameworkURL(ejectURL)
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
