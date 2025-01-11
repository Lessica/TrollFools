//
//  InjectorV3+MachO.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import MachOKit
import OrderedCollections

extension InjectorV3 {

    func isMachO(_ target: URL) -> Bool {
        if (try? MachOKit.loadFromFile(url: target)) != nil {
            true
        } else {
            false
        }
    }

    func isProtectedMachO(_ target: URL) throws -> Bool {
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case .machO(let machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case .encryptionInfo(let encryptionInfoCommand):
                    if encryptionInfoCommand.cryptid != 0 {
                        return true
                    }
                case .encryptionInfo64(let encryptionInfoCommand):
                    if encryptionInfoCommand.cryptid != 0 {
                        return true
                    }
                default:
                    continue
                }
            }
        case .fat(let fatFile):
            let machOFiles = try fatFile.machOFiles()
            for machOFile in machOFiles {
                for command in machOFile.loadCommands {
                    switch command {
                    case .encryptionInfo(let encryptionInfoCommand):
                        if encryptionInfoCommand.cryptid != 0 {
                            return true
                        }
                    case .encryptionInfo64(let encryptionInfoCommand):
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

        let loadedDylibs = try loadedDylibsOfMachO(target).compactMap({ resolveLoadCommand($0) })
        for dylib in loadedDylibs {
            newCollected = try linkedDylibsRecursivelyOfMachO(dylib, collected: newCollected)
        }

        return newCollected
    }

    func loadedDylibsOfMachO(_ target: URL) throws -> OrderedSet<String> {
        var dylibs = OrderedSet<String>()
        let machOFile = try MachOKit.loadFromFile(url: target)
        switch machOFile {
        case .machO(let machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case .loadDylib(let loadDylibCommand):
                    dylibs.append(loadDylibCommand.dylib(in: machOFile).name)
                case .loadWeakDylib(let loadWeakDylibCommand):
                    dylibs.append(loadWeakDylibCommand.dylib(in: machOFile).name)
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
                        dylibs.append(loadDylibCommand.dylib(in: machOFile).name)
                    case .loadWeakDylib(let loadWeakDylibCommand):
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
        case .machO(let machOFile):
            for command in machOFile.loadCommands {
                switch command {
                case .rpath(let rpathCommand):
                    paths.append(rpathCommand.path(in: machOFile))
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
        case .machO(let machOFile):
            if let codeSign = machOFile.codeSign, let teamID = codeSign.codeDirectory?.teamId(in: codeSign) {
                return teamID
            }
        case .fat(let fatFile):
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
