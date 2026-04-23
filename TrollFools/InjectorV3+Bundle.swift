//
//  InjectorV3+Bundle.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation
import OrderedCollections

extension InjectorV3 {
    // MARK: - Constants

    static let ignoredDylibAndFrameworkNames: Set<String> = [
        "cydiasubstrate",
        "cydiasubstrate.framework",
        "ellekit",
        "ellekit.framework",
        "libsubstrate.dylib",
        "libsubstitute.dylib",
        "libellekit.dylib",
    ]

    static let substrateName = "CydiaSubstrate"
    static let substrateFwkName = "CydiaSubstrate.framework"

    fileprivate static let infoPlistName = "Info.plist"
    fileprivate static let injectedMarkerName = ".troll-fools"

    // MARK: - Instance Methods

    var hasInjectedAsset: Bool {
        !injectedAssetURLsInBundle(bundleURL).isEmpty
    }

    // MARK: - Shared Methods

    func frameworkMachOsInBundle(_ target: URL) throws -> OrderedSet<URL> {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        let executableURL = try locateExecutableInBundle(target)
        precondition(isMachO(executableURL), "Not a Mach-O: \(executableURL.path)")

        let frameworksURL = target.appendingPathComponent("Frameworks")
        let frameworksExist = FileManager.default.fileExists(atPath: frameworksURL.path)

        DDLogInfo("Scanning Mach-Os in \(target.lastPathComponent), Frameworks exists: \(frameworksExist)", ddlog: logger)

        let linkedDylibs = try linkedDylibsRecursivelyOfMachO(executableURL)
        DDLogInfo("Linked dylibs (\(linkedDylibs.count)): \(linkedDylibs.map { $0.lastPathComponent })", ddlog: logger)

        var enumeratedMachOs = OrderedSet<URL>()
        if let enumerator = FileManager.default.enumerator(
            at: frameworksURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let itemURL as URL in enumerator {
                if checkIsInjectedBundle(itemURL) || enumerator.level > 2 {
                    enumerator.skipDescendants()
                    continue
                }

                // Skip backup files created before injection
                if itemURL.path.hasSuffix(".\(Self.alternateSuffix)") {
                    continue
                }

                let itemExt = itemURL.pathExtension.lowercased()
                if enumerator.level == 2 && (itemExt.isEmpty || itemExt == "dylib") && isMachO(itemURL) {
                    enumeratedMachOs.append(itemURL)
                    continue
                }

                // Scan bare dylibs at level 1 (directly in Frameworks/)
                if enumerator.level == 1 && itemExt == "dylib" && isMachO(itemURL) {
                    enumeratedMachOs.append(itemURL)
                    continue
                }
            }
        }

        DDLogInfo("Enumerated \(enumeratedMachOs.count) items", ddlog: logger)

        var machOs = linkedDylibs.intersection(enumeratedMachOs)
        DDLogInfo("Intersection: \(machOs.count) linked Mach-Os in Frameworks/", ddlog: logger)

        // Fallback: if none of the Mach-Os in Frameworks/ are statically linked
        // by the main binary (e.g. Unity apps use dlopen), use all available Mach-Os.
        if machOs.isEmpty && !enumeratedMachOs.isEmpty {
            if useFrameworkEnumerationFallback {
                didUseMachOEnumerationFallback = true

                var excludedSwiftRuntimeCount = 0
                var excludedIgnoredNameCount = 0
                let filteredMachOs = enumeratedMachOs.filter { url in
                    let nameLower = url.lastPathComponent.lowercased()
                    if nameLower.hasPrefix("libswift") {
                        excludedSwiftRuntimeCount += 1
                        return false
                    }
                    if Self.ignoredDylibAndFrameworkNames.contains(nameLower) {
                        excludedIgnoredNameCount += 1
                        return false
                    }
                    return true
                }

                let excludedCount = enumeratedMachOs.count - filteredMachOs.count
                DDLogWarn(
                    "No statically linked Mach-Os found, falling back to \(filteredMachOs.count) filtered Mach-Os in Frameworks/ (excluded \(excludedCount): \(excludedSwiftRuntimeCount) Swift runtime, \(excludedIgnoredNameCount) ignored by name)",
                    ddlog: logger
                )

                machOs = OrderedSet(filteredMachOs)
            } else {
                DDLogWarn("No statically linked Mach-Os found, fallback is disabled by settings", ddlog: logger)
            }
        }

        // Filter out previously-injected Mach-Os by diffing current vs. backup load commands.
        // Any load command present in the current binary but absent from its backup was added by injection.
        var injectedAssetNames = Set<String>()
        for machO in (enumeratedMachOs.elements + [executableURL]) where hasAlternate(machO) {
            if let current = try? loadedDylibsOfMachO(machO),
               let original = try? loadedDylibsOfMachO(Self.alternateURL(for: machO))
            {
                for name in current where !original.contains(name) {
                    injectedAssetNames.insert(URL(fileURLWithPath: name).lastPathComponent)
                }
            }
        }
        if !injectedAssetNames.isEmpty {
            let preFilterCount = machOs.count
            machOs = machOs.filter { !injectedAssetNames.contains($0.lastPathComponent) }
            let excludedCount = preFilterCount - machOs.count
            if excludedCount > 0 {
                DDLogInfo(
                    "Excluded \(excludedCount) previously-injected Mach-Os by backup diff: \(injectedAssetNames.sorted())",
                    ddlog: logger
                )
            }
        }

        var sortedMachOs: [URL] =
            switch injectStrategy {
        case .lexicographic:
            machOs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        case .fast:
            try machOs
                .sorted { url1, url2 in
                    let size1 = (try url1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    let size2 = (try url2.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return if size1 == size2 {
                        url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                    } else {
                        size1 < size2
                    }
                }
        case .preorder:
            machOs.elements
        case .postorder:
            machOs.reversed()
        }

        DDLogWarn("Strategy \(injectStrategy.rawValue)", ddlog: logger)
        DDLogInfo("Sorted Mach-Os \(sortedMachOs.map { $0.lastPathComponent })", ddlog: logger)

        if preferMainExecutable {
            sortedMachOs.insert(executableURL, at: 0)
            DDLogWarn("Prefer main executable", ddlog: logger)
        } else {
            sortedMachOs.append(executableURL)
        }

        return OrderedSet(sortedMachOs)
    }

    func injectedAssetURLsInBundle(_ target: URL) -> [URL] {
        return (injectedBundleURLsInBundle(target) + injectedDylibAndFrameworkURLsInBundle(target))
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
    }

    fileprivate func injectedBundleURLsInBundle(_ target: URL) -> [URL] {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        guard let bundleContentURLs = try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        let bundleURLs = bundleContentURLs
            .filter {
                $0.pathExtension.lowercased() == "bundle" &&
                !Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent.lowercased())
            }
            .filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }
            .filter {
                checkIsInjectedBundle($0)
            }
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })

        return bundleURLs
    }

    fileprivate func injectedDylibAndFrameworkURLsInBundle(_ target: URL) -> [URL] {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        let frameworksURL = target.appendingPathComponent("Frameworks")
        guard let frameworksContentURLs = try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil) else {
            return []
        }

        let dylibURLs = frameworksContentURLs
            .filter {
                $0.pathExtension.lowercased() == "dylib" &&
                    !$0.lastPathComponent.hasPrefix("libswift") &&
                !Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent.lowercased())
            }
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })

        let frameworkURLs = frameworksContentURLs
            .filter {
                $0.pathExtension.lowercased() == "framework" &&
                !Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent.lowercased())
            }
            .filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }
            .filter {
                checkIsInjectedBundle($0)
            }
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })

        return dylibURLs + frameworkURLs
    }

    func markBundlesAsInjected(_ bundleURLs: [URL], privileged: Bool) throws {
        let filteredURLs = bundleURLs.filter { checkIsBundle($0) }
        precondition(filteredURLs.count == bundleURLs.count, "Not all urls are bundles")

        if privileged {
            let markerURL = temporaryDirectoryURL.appendingPathComponent(Self.injectedMarkerName)
            try Data().write(to: markerURL, options: .atomic)
            try cmdChangeOwnerToInstalld(markerURL, recursively: false)

            try filteredURLs.forEach {
                try cmdCopy(
                    from: markerURL,
                    to: $0.appendingPathComponent(Self.injectedMarkerName),
                    clone: true,
                    overwrite: true
                )
            }
        } else {
            try filteredURLs.forEach {
                try Data().write(to: $0.appendingPathComponent(Self.injectedMarkerName), options: .atomic)
            }
        }
    }

    func identifierOfBundle(_ target: URL) throws -> String {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        if let bundleIdentifier = Bundle(url: target)?.bundleIdentifier {
            return bundleIdentifier
        }

        let infoPlistURL = target.appendingPathComponent(Self.infoPlistName)
        let infoPlistData = try Data(contentsOf: infoPlistURL)

        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any]
        else {
            throw Error.generic(String(format: NSLocalizedString("Failed to parse: %@", comment: ""), infoPlistURL.path))
        }

        guard let bundleIdentifier = infoPlist["CFBundleIdentifier"] as? String else {
            throw Error.generic(String(format: NSLocalizedString("Failed to find entry CFBundleIdentifier in: %@", comment: ""), infoPlistURL.path))
        }

        return bundleIdentifier
    }

    func locateFrameworksDirectoryInBundle(_ target: URL) throws -> URL {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        let frameworksDirectoryURL = target.appendingPathComponent("Frameworks")
        if !FileManager.default.fileExists(atPath: frameworksDirectoryURL.path) {
            try? cmdMakeDirectory(at: frameworksDirectoryURL)
        }

        return frameworksDirectoryURL
    }

    func locateExecutableInBundle(_ target: URL) throws -> URL {
        precondition(checkIsBundle(target), "Not a bundle: \(target.path)")

        if let executableURL = Bundle(url: target)?.executableURL {
            return executableURL
        }

        let infoPlistURL = target.appendingPathComponent(Self.infoPlistName)
        let infoPlistData = try Data(contentsOf: infoPlistURL)

        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any]
        else {
            throw Error.generic(String(format: NSLocalizedString("Failed to parse: %@", comment: ""), infoPlistURL.path))
        }

        guard let executableName = infoPlist["CFBundleExecutable"] as? String else {
            throw Error.generic(String(format: NSLocalizedString("Failed to find entry CFBundleExecutable in: %@", comment: ""), infoPlistURL.path))
        }

        let executableURL = target.appendingPathComponent(executableName)
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw Error.generic(String(format: NSLocalizedString("Failed to locate main executable: %@", comment: ""), executableURL.path))
        }

        return executableURL
    }

    func checkIsEligibleAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else {
            return false
        }

        let frameworksURL = target.appendingPathComponent("Frameworks")
        return !((try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil).isEmpty) ?? true)
    }

    func checkIsInjectedAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else {
            return false
        }

        let frameworksURL = target.appendingPathComponent("Frameworks")
        let substrateFwkURL = frameworksURL.appendingPathComponent(Self.substrateFwkName)

        return FileManager.default.fileExists(atPath: substrateFwkURL.path)
    }

    func checkIsInjectedBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else {
            return false
        }

        let markerURL = target.appendingPathComponent(Self.injectedMarkerName)
        return FileManager.default.fileExists(atPath: markerURL.path)
    }

    func checkIsBundle(_ target: URL) -> Bool {
        let values = try? target.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let isDirectory = values?.isDirectory ?? false
        let isPackage = values?.isPackage ?? false
        let pathExt = target.pathExtension.lowercased()
        return isPackage || (isDirectory && (pathExt == "app" || pathExt == "bundle" || pathExt == "framework"))
    }

    func checkIsDirectory(_ target: URL) -> Bool {
        let values = try? target.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory ?? false
    }
}
