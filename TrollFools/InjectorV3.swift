//
//  InjectorV3.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/9.
//

import CocoaLumberjackSwift
import Foundation

final class InjectorV3 {
    enum LoggerType {
        case os
        case file
    }

    static let temporaryRoot: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
        .appendingPathComponent("InjectorV3", isDirectory: true)

    static let main = try! InjectorV3(Bundle.main.bundleURL)

    let bundleURL: URL
    let temporaryDirectoryURL: URL
    let isPrivileged: Bool = geteuid() == 0

    var appID: String!
    var teamID: String!

    private(set) var executableURL: URL!
    private(set) var frameworksDirectoryURL: URL!
    private(set) var logsDirectoryURL: URL!

    var useWeakReference: Bool = false
    var preferMainExecutable: Bool = false
    var injectStrategy: Strategy = .lexicographic

    let logger: DDLog
    let loggerType: LoggerType

    private init() { fatalError("Not implemented") }

    init(_ bundleURL: URL, loggerType: LoggerType = .file) throws {
        self.bundleURL = bundleURL
        temporaryDirectoryURL = Self.temporaryRoot
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)

        logger = DDLog()
        self.loggerType = loggerType

        let executableURL = try locateExecutableInBundle(bundleURL)
        let frameworksDirectoryURL = try locateFrameworksDirectoryInBundle(bundleURL)
        let appID = try identifierOfBundle(bundleURL)
        let teamID = try teamIdentifierOfMachO(executableURL) ?? ""

        self.appID = appID
        self.teamID = teamID
        self.executableURL = executableURL
        self.frameworksDirectoryURL = frameworksDirectoryURL
        logsDirectoryURL = temporaryDirectoryURL.appendingPathComponent("Logs/\(appID)")

        setupLoggers()
    }

    // MARK: - Instance Methods

    func terminateApp() {
        TFUtilKillAll(executableURL.lastPathComponent, true)
    }

    // MARK: - Logger

    private func setupLoggers() {
        if loggerType == .file {
            try? FileManager.default.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)

            let fileLogger = DDFileLogger(logFileManager: DDLogFileManagerDefault(logsDirectory: logsDirectoryURL.path))

            fileLogger.rollingFrequency = 60 * 60 * 24
            fileLogger.logFileManager.maximumNumberOfLogFiles = 7
            fileLogger.doNotReuseLogFiles = true

            logger.add(fileLogger)
        }

        logger.add(DDOSLogger.sharedInstance)

        DDLogWarn("Logger setup \(appID!)", asynchronous: false, ddlog: logger)
    }

    var latestLogFileURL: URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: logsDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey]
        ) else {
            return nil
        }

        var latestLogFileURL: URL?
        var latestCreationDate: Date?
        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey]),
                  let isRegularFile = resourceValues.isRegularFile, isRegularFile,
                  let creationDate = resourceValues.creationDate
            else {
                continue
            }

            if latestCreationDate == nil || creationDate > latestCreationDate! {
                latestLogFileURL = fileURL
                latestCreationDate = creationDate
            }
        }

        return latestLogFileURL
    }
}
