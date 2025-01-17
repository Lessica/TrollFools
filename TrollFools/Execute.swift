//
//  Execute.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import Foundation

enum Execute {

    @discardableResult
    static func rootSpawn(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        ddlog: DDLog = .sharedInstance
    ) throws -> AuxiliaryExecute.TerminationReason {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment.merging([
                "DISABLE_TWEAKS": "1",
            ], uniquingKeysWith: { $1 }),
            personaOptions: .init(uid: 0, gid: 0),
            ddlog: ddlog
        )
        if !receipt.stdout.isEmpty {
            DDLogVerbose("Process \(receipt.pid) output: \(receipt.stdout)", ddlog: ddlog)
        }
        if !receipt.stderr.isEmpty {
            DDLogVerbose("Process \(receipt.pid) error: \(receipt.stderr)", ddlog: ddlog)
        }
        return receipt.terminationReason
    }

    static func rootSpawnWithOutputs(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        ddlog: DDLog = .sharedInstance
    ) throws -> AuxiliaryExecute.ExecuteReceipt {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment.merging([
                "DISABLE_TWEAKS": "1",
            ], uniquingKeysWith: { $1 }),
            personaOptions: .init(uid: 0, gid: 0),
            ddlog: ddlog
        )
        if !receipt.stdout.isEmpty {
            DDLogVerbose("Process \(receipt.pid) output: \(receipt.stdout)", ddlog: ddlog)
        }
        if !receipt.stderr.isEmpty {
            DDLogVerbose("Process \(receipt.pid) error: \(receipt.stderr)", ddlog: ddlog)
        }
        return receipt
    }
}
