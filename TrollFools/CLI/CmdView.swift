//
//  CmdView.swift
//  TrollFools
//
//  Created by Rachel on 10/3/2025.
//

import ArgumentParser
import Foundation

struct CmdView: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View the details of the specified application."
    )

    @Argument(help: "The bundle identifier of the application.")
    var bundleIdentifier: String

    func run() throws {
        guard let app = LSApplicationProxy(forIdentifier: bundleIdentifier),
              let bundleURL = app.bundleURL()
        else {
            throw ArgumentParser.ValidationError("The specified application does not exist.")
        }
        var pluginContent = ""
        try InjectorV3(bundleURL, loggerType: .os)
            .injectedAssetURLsInBundle(bundleURL)
            .enumerated()
            .forEach { url in
                pluginContent += "PLUGIN-\(url.offset) = \(url.element.path)\n"
            }
        print("""
ID = \(app.applicationIdentifier() ?? "(null)")
NAME = \(app.localizedName() ?? "(null)")
VERSION = \(app.shortVersionString() ?? "(null)")
TYPE = \(app.applicationType() ?? "(null)")
TEAM = \(app.teamID() ?? "(null)")
BUNDLE = \(app.bundleURL()?.path ?? "(null)")
\(pluginContent)
""")
    }
}
