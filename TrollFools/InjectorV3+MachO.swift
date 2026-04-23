//
//  InjectorV3+MachO.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import Foundation
import MachOKit
import OrderedCollections

extension InjectorV3 {
    // Mach-O magic numbers (both native and byte-swapped).
    // MachOKit's loadFromFile can hit a Swift runtime trap (brk #1) on files
    // that are not Mach-O — `try?` does not catch those — so callers must
    // screen with this cheap pre-check before invoking MachOKit.
    private static let machOMagics: Set<UInt32> = [
        0xFEEDFACE, 0xCEFAEDFE,
        0xFEEDFACF, 0xCFFAEDFE,
        0xCAFEBABE, 0xBEBAFECA,
        0xCAFEBABF, 0xBFBAFECA,
    ]

    fileprivate func hasMachOMagic(_ target: URL) -> Bool {
        guard let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize),
              size >= 32
        else {
            return false
        }
        guard let handle = try? FileHandle(forReadingFrom: target) else {
            return false
        }
        defer { try? handle.close() }
        let head: Data?
        if #available(iOS 13.4, *) {
            head = try? handle.read(upToCount: 4)
        } else {
            head = handle.readData(ofLength: 4)
        }
        guard let data = head, data.count == 4 else {
            return false
        }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return Self.machOMagics.contains(magic)
    }

    func isMachO(_ target: URL) -> Bool {
        guard hasMachOMagic(target) else {
            return false
        }
        return (try? MachOKit.loadFromFile(url: target)) != nil
    }

    func isProtectedMachO(_ target: URL) throws -> Bool {
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case let .machO(machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case let .encryptionInfo(encryptionInfoCommand):
                    if encryptionInfoCommand.cryptid != 0 {
                        return true
                    }
                case let .encryptionInfo64(encryptionInfoCommand):
                    if encryptionInfoCommand.cryptid != 0 {
                        return true
                    }
                default:
                    continue
                }
            }
        case let .fat(fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case let .encryptionInfo(encryptionInfoCommand):
                        if encryptionInfoCommand.cryptid != 0 {
                            return true
                        }
                    case let .encryptionInfo64(encryptionInfoCommand):
                        if encryptionInfoCommand.cryptid != 0 {
                            return true
                        }
                    default:
                        continue
                    }
                }
            }
        }
        return false
    }

    func linkedDylibsRecursivelyOfMachO(_ target: URL, collected: OrderedSet<URL> = []) throws -> OrderedSet<URL> {
        if collected.contains(target) {
            return collected
        }

        var newCollected = collected
        newCollected.append(target)

        // If the Mach-O has a backup (made before injection), read load commands
        // from the original to avoid picking up previously-injected dylibs.
        let readTarget = hasAlternate(target) ? Self.alternateURL(for: target) : target
        let loadedDylibs = try loadedDylibsOfMachO(readTarget).compactMap({ resolveLoadCommand($0) })
        for dylib in loadedDylibs {
            newCollected = try linkedDylibsRecursivelyOfMachO(dylib, collected: newCollected)
        }

        return newCollected
    }

    func loadedDylibsOfMachO(_ target: URL) throws -> OrderedSet<String> {
        var dylibs = OrderedSet<String>()
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case let .machO(machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case let .loadDylib(loadDylibCommand):
                    dylibs.append(loadDylibCommand.dylib(in: machOFile).name)
                case let .loadWeakDylib(loadWeakDylibCommand):
                    dylibs.append(loadWeakDylibCommand.dylib(in: machOFile).name)
                default:
                    continue
                }
            }
        case let .fat(fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case let .loadDylib(loadDylibCommand):
                        dylibs.append(loadDylibCommand.dylib(in: machOFile).name)
                    case let .loadWeakDylib(loadWeakDylibCommand):
                        dylibs.append(loadWeakDylibCommand.dylib(in: machOFile).name)
                    default:
                        continue
                    }
                }
            }
        }
        return dylibs
    }

    func runtimePathsOfMachO(_ target: URL) throws -> OrderedSet<String> {
        var paths = OrderedSet<String>()
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case let .machO(machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case let .rpath(rpathCommand):
                    paths.append(rpathCommand.path(in: machOFile))
                default:
                    continue
                }
            }
        case let .fat(fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case let .rpath(rpathCommand):
                        paths.append(rpathCommand.path(in: machOFile))
                    default:
                        continue
                    }
                }
            }
        }
        return paths
    }

    func teamIdentifierOfMachO(_ target: URL) throws -> String? {
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case let .machO(machOFile):
            if let codeSign = machOFile.codeSign, let teamID = codeSign.codeDirectory?.teamId(in: codeSign) {
                return teamID
            }
        case let .fat(fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                if let codeSign = machOFile.codeSign, let teamID = codeSign.codeDirectory?.teamId(in: codeSign) {
                    return teamID
                }
            }
        }
        return nil
    }

    fileprivate func resolveLoadCommand(_ name: String) -> URL? {
        guard (name.hasPrefix("@rpath/") && !name.hasPrefix("@rpath/libswift")) || name.hasPrefix("@executable_path/") else {
            return nil
        }

        var resolvedName = name
        resolvedName = resolvedName
            .replacingOccurrences(of: "@executable_path/", with: executableURL.deletingLastPathComponent().path + "/")
        resolvedName = resolvedName
            .replacingOccurrences(of: "@rpath/", with: frameworksDirectoryURL.path + "/")

        let resolvedURL = URL(fileURLWithPath: resolvedName)
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            return nil
        }

        return resolvedURL
    }
}
