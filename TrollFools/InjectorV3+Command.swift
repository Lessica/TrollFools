//
//  InjectorV3+Command.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/9.
//

import Foundation
import MachOKit

extension InjectorV3 {

    // MARK: - chown

    fileprivate static let chownBinaryURL = Bundle.main.url(forResource: "chown", withExtension: nil)!

    func cmdChangeOwner(_ target: URL, owner: String, groupOwner: String? = nil, recursively: Bool = false) throws {
        if isPrivileged {
            try rootChangeOwner(target, owner: owner, groupOwner: groupOwner, recursively: recursively)
            return
        }
        var args = [String]()
        if recursively {
            args.append("-R")
        }
        if let groupOwner {
            args.append(String(format: "%@:%@", owner, groupOwner))
        } else {
            args.append(owner)
        }
        args.append(target.path)
        let retCode = try Execute.rootSpawn(binary: Self.chownBinaryURL.path, arguments: args, ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("chown", reason: retCode)
        }
    }

    func cmdChangeOwnerToInstalld(_ target: URL, recursively: Bool = false) throws {
        try cmdChangeOwner(target, owner: "_installd", groupOwner: "_installd", recursively: recursively)
    }

    private func rootChangeOwner(_ target: URL, owner: String, groupOwner: String? = nil, recursively: Bool = false) throws {
        let attrs: [FileAttributeKey : Any] = [
            .ownerAccountName: owner,
            .groupOwnerAccountName: groupOwner ?? owner,
        ]
        if !recursively {
            try FileManager.default.setAttributes(attrs, ofItemAtPath: target.path)
            return
        }
        if let enumerator = FileManager.default.enumerator(at: target, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                try FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
            }
        }
    }

    // MARK: - cp

    fileprivate static let cpBinaryURL: URL = {
        if #available(iOS 16, *) {
            Bundle.main.url(forResource: "cp", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "cp-15", withExtension: nil)!
        }
    }()

    func cmdCopy(from srcURL: URL, to destURL: URL, clone: Bool = false, overwrite: Bool = false) throws {
        if isPrivileged {
            try rootCopy(from: srcURL, to: destURL, overwrite: overwrite)
            return
        }
        if overwrite {
            try? cmdRemove(destURL, recursively: true)
        }
        var args = [String]()
        if clone {
            args.append("--reflink=auto")
        }
        args += ["-rfp", srcURL.path, destURL.path]
        let retCode = try Execute.rootSpawn(binary: Self.cpBinaryURL.path, arguments: args, ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("cp", reason: retCode)
        }
    }

    private func rootCopy(from srcURL: URL, to destURL: URL, overwrite: Bool = false) throws {
        if overwrite {
            try? rootRemove(destURL, recursively: true)
        }
        try FileManager.default.copyItem(at: srcURL, to: destURL)
    }

    // MARK: - ldid

    fileprivate static let ldidBinaryURL: URL = {
        Bundle.main.url(forResource: "ldid", withExtension: nil)!
    }()

    func cmdPseudoSign(_ target: URL, force: Bool = false) throws {

        var hasCodeSign = false
        var preservesEntitlements = false

        let targetFile = try MachOKit.loadFromFile(url: target)
        switch targetFile {
        case .machO(let machOFile):
            preservesEntitlements = machOFile.header.fileType == .execute
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
                preservesEntitlements = machOFile.header.fileType == .execute
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

        if preservesEntitlements {

            var receipt: AuxiliaryExecute.ExecuteReceipt

            receipt = try Execute.rootSpawnWithOutputs(binary: Self.ldidBinaryURL.path, arguments: [
                "-e", target.path,
            ], ddlog: logger)

            guard case .exit(let code) = receipt.terminationReason, code == EXIT_SUCCESS else {
                try throwCommandFailure("ldid", reason: receipt.terminationReason)
            }

            let xmlContent = receipt.stdout
            let xmlURL = temporaryDirectoryURL
                .appendingPathComponent("\(UUID().uuidString)_\(target.lastPathComponent)")
                .appendingPathExtension("xml")

            try xmlContent.write(to: xmlURL, atomically: true, encoding: .utf8)

            receipt = try Execute.rootSpawnWithOutputs(binary: Self.ldidBinaryURL.path, arguments: [
                "-S\(xmlURL.path)", target.path,
            ], ddlog: logger)

            guard case .exit(let code) = receipt.terminationReason, code == EXIT_SUCCESS else {
                try throwCommandFailure("ldid", reason: receipt.terminationReason)
            }
        } else {

            let retCode = try Execute.rootSpawn(binary: Self.ldidBinaryURL.path, arguments: [
                "-S", target.path,
            ], ddlog: logger)

            guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
                try throwCommandFailure("ldid", reason: retCode)
            }
        }
    }

    // MARK: - mkdir

    fileprivate static let mkdirBinaryURL = Bundle.main.url(forResource: "mkdir", withExtension: nil)!

    func cmdMakeDirectory(at target: URL, withIntermediateDirectories: Bool = false) throws {
        if isPrivileged {
            try rootMakeDirectory(at: target, withIntermediateDirectories: withIntermediateDirectories)
            return
        }
        var args = [String]()
        if withIntermediateDirectories {
            args.append("-p")
        }
        args.append(target.path)
        let retCode = try Execute.rootSpawn(binary: Self.mkdirBinaryURL.path, arguments: args, ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("mkdir", reason: retCode)
        }
    }

    private func rootMakeDirectory(at target: URL, withIntermediateDirectories: Bool = false) throws {
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: withIntermediateDirectories)
    }

    // MARK: - mv

    fileprivate static let mvBinaryURL: URL = {
        if #available(iOS 16, *) {
            Bundle.main.url(forResource: "mv", withExtension: nil)!
        } else {
            Bundle.main.url(forResource: "mv-15", withExtension: nil)!
        }
    }()

    func cmdMove(from srcURL: URL, to destURL: URL, overwrite: Bool = false) throws {
        if isPrivileged {
            try rootMove(from: srcURL, to: destURL, overwrite: overwrite)
            return
        }
        if overwrite {
            try? cmdRemove(destURL, recursively: true)
        }
        var args = [String]()
        if overwrite {
            args.append("-f")
        }
        args += [srcURL.path, destURL.path]
        let retCode = try Execute.rootSpawn(binary: Self.mvBinaryURL.path, arguments: args, ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("mv", reason: retCode)
        }
    }

    private func rootMove(from srcURL: URL, to destURL: URL, overwrite: Bool = false) throws {
        if overwrite {
            try? rootRemove(destURL, recursively: true)
        }
        try FileManager.default.moveItem(at: srcURL, to: destURL)
    }

    // MARK: - rm

    fileprivate static let rmBinaryURL = Bundle.main.url(forResource: "rm", withExtension: nil)!

    func cmdRemove(_ target: URL, recursively: Bool = false) throws {
        if isPrivileged {
            try rootRemove(target, recursively: recursively)
            return
        }
        let retCode = try Execute.rootSpawn(binary: Self.rmBinaryURL.path, arguments: [
            recursively ? "-rf" : "-f", target.path,
        ], ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("rm", reason: retCode)
        }
    }

    private func rootRemove(_ target: URL, recursively: Bool = false) throws {
        if !recursively {
            let retCode = target.withUnsafeFileSystemRepresentation { unlink($0) }
            guard retCode == 0 else {
                throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EPERM)
            }
            return
        }
        try FileManager.default.removeItem(at: target)
    }

    // MARK: - ct_bypass

    fileprivate static let ctBypassBinaryURL = Bundle.main.url(forResource: "ct_bypass", withExtension: nil)!

    func cmdCoreTrustBypass(_ target: URL, teamID: String) throws {
        try cmdPseudoSign(target)
        let retCode = try Execute.rootSpawn(binary: Self.ctBypassBinaryURL.path, arguments: [
            "-r", "-i", target.path, "-t", teamID,
        ], ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("ct_bypass", reason: retCode)
        }
    }

    // MARK: - insert_dylib

    fileprivate static let insertDylibBinaryURL = Bundle.main.url(forResource: "insert_dylib", withExtension: nil)!

    func cmdInsertLoadCommandDylib(_ target: URL, name: String, weak: Bool = false) throws {
        let dylibs = try loadedDylibsOfMachO(target)
        if dylibs.contains(name) {
            return
        }
        var args = [
            name, target.path,
            "--inplace", "--overwrite", "--no-strip-codesig", "--all-yes",
        ]
        if weak {
            args.append("--weak")
        }
        let retCode = try Execute.rootSpawn(binary: Self.insertDylibBinaryURL.path, arguments: args, ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("insert_dylib", reason: retCode)
        }
    }

    // MARK: - install_name_tool

    fileprivate static let installNameToolBinaryURL = Bundle.main.url(forResource: "install_name_tool", withExtension: nil)!

    func cmdInsertLoadCommandRuntimePath(_ target: URL, name: String) throws {
        let rpaths = try runtimePathsOfMachO(target)
        if rpaths.contains(name) {
            return
        }
        try cmdPseudoSign(target, force: true)
        let retCode = try Execute.rootSpawn(binary: Self.installNameToolBinaryURL.path, arguments: [
            "-add_rpath", name, target.path,
        ], ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("install_name_tool", reason: retCode)
        }
    }

    func cmdChangeLoadCommandDylib(_ target: URL, from srcName: String, to destName: String) throws {
        try cmdPseudoSign(target, force: true)
        let retCode = try Execute.rootSpawn(binary: Self.installNameToolBinaryURL.path, arguments: [
            "-change", srcName, destName, target.path,
        ], ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("install-name-tool", reason: retCode)
        }
    }

    // MARK: - optool

    fileprivate static let optoolBinaryURL = Bundle.main.url(forResource: "optool", withExtension: nil)!

    func cmdRemoveLoadCommandDylib(_ target: URL, name: String) throws {
        let dylibs = try loadedDylibsOfMachO(target)
        guard dylibs.contains(name) else {
            return
        }
        let retCode = try Execute.rootSpawn(binary: Self.optoolBinaryURL.path, arguments: [
            "uninstall", "-p", name, "-t", target.path,
        ], ddlog: logger)
        guard case .exit(let code) = retCode, code == EXIT_SUCCESS else {
            try throwCommandFailure("optool", reason: retCode)
        }
    }

    // MARK: - Error Handling

    fileprivate func throwCommandFailure(_ command: String, reason: AuxiliaryExecute.TerminationReason) throws -> Never {
        switch reason {
        case .exit(let code):
            throw Error.generic(String(format: NSLocalizedString("%@ exited with code %d", comment: ""), command, code))
        case .uncaughtSignal(let signal):
            throw Error.generic(String(format: NSLocalizedString("%@ terminated with signal %d", comment: ""), command, signal))
        }
    }
}
