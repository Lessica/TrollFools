//
//  Entry.swift
//  trollfoolscli
//
//  Created by 82Flex on 3/8/25.
//

import ArgumentParser
import Foundation

@main
struct Entry: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "trollfoolscli",
        abstract: "In-place tweak injection with insert_dylib and ChOma.",
        version: TFGetDisplayVersion(),
        subcommands: [
            CmdList.self,
            CmdView.self,
            CmdInject.self,
            CmdEject.self,
        ]
    )
}
