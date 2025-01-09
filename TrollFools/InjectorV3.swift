//
//  InjectorV3.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/9.
//

import SwiftUI

final class InjectorV3 {

    static let main = try! InjectorV3(Bundle.main.bundleURL)

    let bundleURL: URL
    let temporaryDirectoryURL: URL

    var appID: String!
    var teamID: String!

    private(set) var executableURL: URL!
    private(set) var frameworksDirectoryURL: URL!

    private(set) var useWeakReference: AppStorage<Bool>!
    private(set) var preferMainExecutable: AppStorage<Bool>!

    private init() { fatalError("Not implemented") }

    init(_ bundleURL: URL) throws {

        self.bundleURL = bundleURL
        self.temporaryDirectoryURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: bundleURL,
            create: true
        )

        let executableURL = try locateExecutableInBundle(bundleURL)
        let frameworksDirectoryURL = try locateFrameworksDirectoryInBundle(bundleURL)
        let appID = try identifierOfBundle(bundleURL)
        let teamID = try teamIdentifierOfMachO(executableURL) ?? ""

        self.appID = appID
        self.teamID = teamID
        self.executableURL = executableURL
        self.frameworksDirectoryURL = frameworksDirectoryURL

        self.useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(appID)")
        self.preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(appID)")
    }

    deinit {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }

    // MARK: - Instance Methods

    func terminateApp() {
        TFUtilKillAll(executableURL.lastPathComponent, true)
    }
}
