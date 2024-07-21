//
//  Execute.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import Foundation

@_silgen_name("posix_spawnattr_set_persona_np")
private func posix_spawnattr_set_persona_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: uid_t,
    _ flags: UInt32
) -> Int32

@_silgen_name("posix_spawnattr_set_persona_uid_np")
private func posix_spawnattr_set_persona_uid_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: uid_t
) -> Int32

@_silgen_name("posix_spawnattr_set_persona_gid_np")
private func posix_spawnattr_set_persona_gid_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: uid_t
) -> Int32

private let POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE = UInt32(1)

private func WIFEXITED(_ status: Int32) -> Bool {
    _WSTATUS(status) == 0
}

private func _WSTATUS(_ status: Int32) -> Int32 {
    status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
    (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

private func WEXITSTATUS(_ status: Int32) -> Int32 {
    (status >> 8) & 0xff
}

private func WTERMSIG(_ status: Int32) -> Int32 {
    status & 0x7f
}

enum Execute {

    enum TerminationReason {
        case exit(Int32)
        case uncaughtSignal(Int32)
    }

    @discardableResult
    static func spawn(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) throws -> TerminationReason {

        var attrs: posix_spawnattr_t?
        posix_spawnattr_init(&attrs)
        defer { posix_spawnattr_destroy(&attrs) }

        _ = posix_spawnattr_set_persona_np(&attrs, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE)
        _ = posix_spawnattr_set_persona_uid_np(&attrs, 0)
        _ = posix_spawnattr_set_persona_gid_np(&attrs, 0)

        let env = environment
            .map { key, value in "\(key)=\(value)" }
            .reduce(into: [String]()) { $0.append($1) }
            .map { $0.withCString(strdup) }
        defer { env.forEach { free($0) } }

        let args = [binary] + arguments
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
        defer { for case let arg? in argv {
            free(arg)
        } }

        DDLogInfo("Execute \(binary) \(args.joined(separator: " "))")

        var pid: pid_t = 0
        let ret = posix_spawn(&pid, binary, nil, &attrs, argv + [nil], env + [nil])
        if ret != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: ret)!)
        }

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        if WIFSIGNALED(status) {
            let signal = WTERMSIG(status)
            DDLogError("Process \(pid) terminated with uncaught signal \(signal)")
            return .uncaughtSignal(signal)
        } else {
            assert(WIFEXITED(status))

            let exitCode = WEXITSTATUS(status)
            if exitCode == 0 {
                DDLogInfo("Process \(pid) exited successfully")
            } else {
                DDLogError("Process \(pid) exited with code \(exitCode)")
            }

            return .exit(exitCode)
        }
    }
}
