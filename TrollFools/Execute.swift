//
//  Execute.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

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

enum Execute {
    @discardableResult
    static func spawn(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        shouldWait: Bool = false
    ) -> Int? {
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

        var pid: pid_t = 0
        let ret = posix_spawn(&pid, binary, nil, &attrs, argv + [nil], env + [nil])
        if ret != 0 {
            return nil
        }

        if shouldWait {
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            return Int(status)
        }

        return nil
    }
}
