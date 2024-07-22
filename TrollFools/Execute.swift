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
        environment: [String: String] = [:]
    ) throws -> AuxiliaryExecute.TerminationReason {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment,
            personaOptions: .init(uid: 0, gid: 0)
        )
        if !receipt.stdout.isEmpty {
            DDLogInfo("Standard output: \(receipt.stdout)")
        }
        if !receipt.stderr.isEmpty {
            DDLogInfo("Standard error: \(receipt.stderr)")
        }
        return receipt.terminationReason
    }

    static func rootSpawnWithOutputs(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) throws -> AuxiliaryExecute.ExecuteReceipt {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment,
            personaOptions: .init(uid: 0, gid: 0)
        )
        if !receipt.stdout.isEmpty {
            DDLogInfo("Standard output: \(receipt.stdout)")
        }
        if !receipt.stderr.isEmpty {
            DDLogInfo("Standard error: \(receipt.stderr)")
        }
        return receipt
    }
}
