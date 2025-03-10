//
//  CmdList.swift
//  TrollFools
//
//  Created by Rachel on 10/3/2025.
//

import ArgumentParser
import Foundation

struct CmdList: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all the applications."
    )

    @Flag(name: [.customLong("user")], help: "Print user applications only.")
    var userOnly = false

    func run() throws {
        struct App {
            let identifier: String
            let localizedName: String
        }
        (LSApplicationWorkspace.default().allApplications() ?? [])
            .compactMap { app -> App? in
                guard let identifier = app.applicationIdentifier(),
                      let localizedName = app.localizedName()
                else {
                    return nil
                }
                if userOnly, let type = app.applicationType(), type.lowercased() != "user" {
                    return nil
                }
                return App(identifier: identifier, localizedName: localizedName)
            }
            .sorted { $0.identifier < $1.identifier }
            .forEach { app in
                print("\(app.identifier) = \(app.localizedName)")
            }
    }
}
