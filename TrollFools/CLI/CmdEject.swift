//
//  CmdEject.swift
//  TrollFools
//
//  Created by Rachel on 10/3/2025.
//

import ArgumentParser
import Foundation

struct CmdEject: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "eject",
        abstract: "Eject plugins from the specified application."
    )

    @Argument(help: "The bundle identifier of the application.")
    var bundleIdentifier: String

    @Option(name: [.customLong("path"), .customShort("p")], help: "The path of the plugin.")
    var pluginPath: String?

    @Flag(name: [.customLong("all")], help: "Eject all plugins.")
    var ejectAll: Bool = false

    func validate() throws {
        if ejectAll && pluginPath != nil {
            throw ArgumentParser.ValidationError(
                "The --all flag and --path option cannot be used at the same time."
            )
        }
        if !ejectAll && pluginPath == nil {
            throw ArgumentParser.ValidationError(
                "Either --all flag or --path option must be specified."
            )
        }
    }

    func run() throws {
        guard let app = LSApplicationProxy(forIdentifier: bundleIdentifier),
              let bundleURL = app.bundleURL()
        else {
            throw ArgumentParser.ValidationError("The specified application does not exist.")
        }
        if let pluginPath {
            if let pluginURL = URL(string: pluginPath),
               FileManager.default.fileExists(atPath: pluginPath) {
                try InjectorV3(bundleURL, loggerType: .os).eject([pluginURL], shouldDesist: true)
            } else {
                throw ArgumentParser.ValidationError("The specified plugin path is invalid.")
            }
        } else if ejectAll {
            try InjectorV3(bundleURL, loggerType: .os).ejectAll(shouldDesist: true)
        } else {
            throw ArgumentParser.ValidationError("No plugin to eject.")
        }
    }
}
