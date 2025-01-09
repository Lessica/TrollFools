//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import SwiftUI

let kTrollFoolsErrorDomain = "wiki.qaq.TrollFools.error"

@main
struct TrollFoolsApp: SwiftUI.App {

    init() {
        DDLog.add(DDOSLogger.sharedInstance)

        let logsDirectory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/wiki.qaq.TrollFools")

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory.path)
        let fileLogger = DDFileLogger(logFileManager: logFileManager)

        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        DDLog.add(fileLogger)
    }

    var body: some Scene {
        WindowGroup {
            AppListView()
                .environmentObject(AppListModel())
        }
    }
}
