//
//  CmdInject.swift
//  TrollFools
//
//  Created by Rachel on 10/3/2025.
//

import ArgumentParser
import Foundation

struct CmdInject: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "inject",
        abstract: "Inject a persistent payload to a target application"
    )

    @Argument(help: "The bundle identifier of the application.")
    var bundleIdentifier: String

    @Option(name: [.customLong("path"), .customShort("p")], parsing: .upToNextOption, help: "The path of the plugin.")
    var pluginPaths: [String]

    @Flag(name: [.customLong("fast")], help: "Use fast injection strategy.")
    var fastInjection: Bool = false

    @Flag(name: [.customLong("weak")], help: "Use weak reference.")
    var weakReference: Bool = false

    func run() throws {
        guard let app = LSApplicationProxy(forIdentifier: bundleIdentifier),
              let appID = app.applicationIdentifier(),
              let bundleURL = app.bundleURL()
        else {
            throw ArgumentParser.ValidationError("The specified application does not exist.")
        }
        try pluginPaths.forEach {
            guard FileManager.default.fileExists(atPath: $0) else {
                throw ArgumentParser.ValidationError("This plugin does not exist: \($0)")
            }
        }
        let pluginURLs = pluginPaths.compactMap { URL(fileURLWithPath: $0) }
        let injector = try InjectorV3(bundleURL, loggerType: .os)
        if injector.appID.isEmpty {
            injector.appID = appID
        }
        if injector.teamID.isEmpty {
            if let teamID = app.teamID() {
                injector.teamID = teamID
            } else {
                injector.teamID = "0000000000"
            }
        }
        injector.useWeakReference = weakReference
        injector.injectStrategy = fastInjection ? .fast : .lexicographic
        try injector.inject(pluginURLs)
    }
}
