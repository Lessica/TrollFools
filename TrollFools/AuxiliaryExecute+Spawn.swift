//
//  AuxiliaryExecute+Spawn.swift
//  AuxiliaryExecute
//
//  Created by Lakr Aream on 2021/12/6.
//

import CocoaLumberjackSwift
import Foundation

@discardableResult
@_silgen_name("posix_spawn_file_actions_addchdir_np")
private func posix_spawn_file_actions_addchdir_np(
    _ attr: UnsafeMutablePointer<posix_spawn_file_actions_t?>,
    _ dir: UnsafePointer<Int8>
) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_np")
private func posix_spawnattr_set_persona_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: uid_t,
    _ flags: UInt32
) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_uid_np")
private func posix_spawnattr_set_persona_uid_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: uid_t
) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_gid_np")
private func posix_spawnattr_set_persona_gid_np(
    _ attr: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ persona_id: gid_t
) -> Int32

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

private let POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE = UInt32(1)

public extension AuxiliaryExecute {
    /// call posix spawn to begin execute
    /// - Parameters:
    ///   - command: full path of the binary file. eg: "/bin/cat"
    ///   - args: arg to pass to the binary, exclude argv[0] which is the path itself. eg: ["nya"]
    ///   - environment: any environment to be appended/overwrite when calling posix spawn. eg: ["mua" : "nya"]
    ///   - workingDirectory: chdir
    ///   - timeout: any wall timeout if lager than 0, in seconds. eg: 6
    ///   - output: a block call from pipeControlQueue in background when buffer from stdout or stderr available for read
    /// - Returns: execution receipt, see it's definition for details
    @discardableResult
    static func spawn(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        ddlog: DDLog = .sharedInstance,
        setPid: ((pid_t) -> Void)? = nil,
        output: ((String) -> Void)? = nil
    )
        -> ExecuteReceipt
    {
        let outputLock = NSLock()
        let result = spawn(
            command: command,
            args: args,
            environment: environment,
            workingDirectory: workingDirectory,
            personaOptions: personaOptions,
            timeout: timeout,
            ddlog: ddlog,
            setPid: setPid
        ) { str in
            outputLock.lock()
            output?(str)
            outputLock.unlock()
        } stderrBlock: { str in
            outputLock.lock()
            output?(str)
            outputLock.unlock()
        }
        return result
    }

    /// call posix spawn to begin execute and block until the process exits
    /// - Parameters:
    ///   - command: full path of the binary file. eg: "/bin/cat"
    ///   - args: arg to pass to the binary, exclude argv[0] which is the path itself. eg: ["nya"]
    ///   - environment: any environment to be appended/overwrite when calling posix spawn. eg: ["mua" : "nya"]
    ///   - workingDirectory: chdir
    ///   - timeout: any wall timeout if lager than 0, in seconds. eg: 6
    ///   - stdout: a block call from pipeControlQueue in background when buffer from stdout available for read
    ///   - stderr: a block call from pipeControlQueue in background when buffer from stderr available for read
    /// - Returns: execution receipt, see it's definition for details
    static func spawn(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        ddlog: DDLog = .sharedInstance,
        setPid: ((pid_t) -> Void)? = nil,
        stdoutBlock: ((String) -> Void)? = nil,
        stderrBlock: ((String) -> Void)? = nil
    ) -> ExecuteReceipt {
        let sema = DispatchSemaphore(value: 0)
        var receipt: ExecuteReceipt!
        spawn(
            command: command,
            args: args,
            environment: environment,
            workingDirectory: workingDirectory,
            personaOptions: personaOptions,
            timeout: timeout,
            ddlog: ddlog,
            setPid: setPid,
            stdoutBlock: stdoutBlock,
            stderrBlock: stderrBlock
        ) {
            receipt = $0
            sema.signal()
        }
        sema.wait()
        return receipt
    }

    /// call posix spawn to begin execute
    /// - Parameters:
    ///   - command: full path of the binary file. eg: "/bin/cat"
    ///   - args: arg to pass to the binary, exclude argv[0] which is the path itself. eg: ["nya"]
    ///   - environment: any environment to be appended/overwrite when calling posix spawn. eg: ["mua" : "nya"]
    ///   - workingDirectory: chdir file action
    ///   - personaOptions: persona options
    ///   - timeout: any wall timeout if lager than 0, in seconds. eg: 6
    ///   - setPid: called sync when pid available
    ///   - stdoutBlock: a block call from pipeControlQueue in background when buffer from stdout available for read
    ///   - stderrBlock: a block call from pipeControlQueue in background when buffer from stderr available for read
    ///   - completionBlock: a block called from processControlQueue or current queue when the process is finished or an error occurred
    static func spawn(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        ddlog: DDLog = .sharedInstance,
        setPid: ((pid_t) -> Void)? = nil,
        stdoutBlock: ((String) -> Void)? = nil,
        stderrBlock: ((String) -> Void)? = nil,
        completionBlock: ((ExecuteReceipt) -> Void)? = nil
    ) {
        // MARK: PREPARE ATTRIBUTE -

        var attrs: posix_spawnattr_t?
        posix_spawnattr_init(&attrs)
        defer { posix_spawnattr_destroy(&attrs) }

        if let personaOptions {
            posix_spawnattr_set_persona_np(&attrs, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE)
            posix_spawnattr_set_persona_uid_np(&attrs, personaOptions.uid)
            posix_spawnattr_set_persona_gid_np(&attrs, personaOptions.gid)
        }

        // MARK: PREPARE FILE PIPE -

        var pipestdout: [Int32] = [0, 0]
        var pipestderr: [Int32] = [0, 0]

        let bufsiz = Int(exactly: BUFSIZ) ?? 65535

        pipe(&pipestdout)
        pipe(&pipestderr)

        guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1 else {
            let receipt = ExecuteReceipt.failure(error: .openFilePipeFailed)
            completionBlock?(receipt)
            return
        }
        guard fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1 else {
            let receipt = ExecuteReceipt.failure(error: .openFilePipeFailed)
            completionBlock?(receipt)
            return
        }

        // MARK: PREPARE FILE ACTION -

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
        posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])

        if let workingDirectory = workingDirectory {
            posix_spawn_file_actions_addchdir_np(&fileActions, workingDirectory)
        }

        defer { posix_spawn_file_actions_destroy(&fileActions) }

        // MARK: PREPARE ENV -

        var realEnvironmentBuilder: [String] = []
        // before building the environment, we need to read from the existing environment
        do {
            var envBuilder = [String: String]()
            var currentEnv = environ
            while let rawStr = currentEnv.pointee {
                defer { currentEnv += 1 }
                // get the env
                let str = String(cString: rawStr)
                guard let key = str.components(separatedBy: "=").first else {
                    continue
                }
                if !(str.count >= "\(key)=".count) {
                    continue
                }
                // this is to aviod any problem with mua=nya=nya= that ending with =
                let value = String(str.dropFirst("\(key)=".count))
                envBuilder[key] = value
            }
            // now, let's overwrite the environment specified in parameters
            for (key, value) in environment {
                envBuilder[key] = value
            }
            // now, package those items
            for (key, value) in envBuilder {
                realEnvironmentBuilder.append("\(key)=\(value)")
            }
        }
        // making it a c shit
        let realEnv: [UnsafeMutablePointer<CChar>?] = realEnvironmentBuilder.map { $0.withCString(strdup) }
        defer { for case let env? in realEnv { free(env) } }

        // MARK: PREPARE ARGS -

        let args = [command] + args
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
        defer { for case let arg? in argv { free(arg) } }

        // MARK: NOW POSIX_SPAWN -

        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, command, &fileActions, &attrs, argv + [nil], realEnv + [nil])
        if spawnStatus != 0 {
            let receipt = ExecuteReceipt.failure(error: .posixSpawnFailed)
            completionBlock?(receipt)
            return
        }

        DDLogInfo("Spawned process \(pid) command \(args.joined(separator: " "))", ddlog: ddlog)
        setPid?(pid)

        close(pipestdout[1])
        close(pipestderr[1])

        var stdoutStr = ""
        var stderrStr = ""

        // MARK: OUTPUT BRIDGE -

        let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: pipeControlQueue)
        let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: pipeControlQueue)

        let stdoutSem = DispatchSemaphore(value: 0)
        let stderrSem = DispatchSemaphore(value: 0)

        stdoutSource.setCancelHandler {
            close(pipestdout[0])
            stdoutSem.signal()
        }
        stderrSource.setCancelHandler {
            close(pipestderr[0])
            stderrSem.signal()
        }

        stdoutSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            let bytesRead = read(pipestdout[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1, errno == EAGAIN {
                    return
                }
                stdoutSource.cancel()
                return
            }

            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                stdoutStr += str
                stdoutBlock?(str)
            }
        }
        stderrSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }

            let bytesRead = read(pipestderr[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1, errno == EAGAIN {
                    return
                }
                stderrSource.cancel()
                return
            }

            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                stderrStr += str
                stderrBlock?(str)
            }
        }

        stdoutSource.resume()
        stderrSource.resume()

        // MARK: WAIT + TIMEOUT CONTROL -

        let realTimeout = timeout > 0 ? timeout : maxTimeoutValue
        let wallTimeout = DispatchTime.now() + (
            TimeInterval(exactly: realTimeout) ?? maxTimeoutValue
        )
        var status: Int32 = 0
        var wait: pid_t = 0
        var isTimeout = false

        let timerSource = DispatchSource.makeTimerSource(flags: [], queue: processControlQueue)
        timerSource.setEventHandler {
            isTimeout = true
            kill(pid, SIGKILL)
        }

        let processSource = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: processControlQueue)
        processSource.setEventHandler {
            wait = waitpid(pid, &status, 0)

            processSource.cancel()
            timerSource.cancel()

            stdoutSem.wait()
            stderrSem.wait()

            let terminationReason: TerminationReason
            if WIFSIGNALED(status) {
                let signal = WTERMSIG(status)
                DDLogError("Process \(pid) terminated with uncaught signal \(signal)", ddlog: ddlog)
                terminationReason = .uncaughtSignal(signal)
            } else {
                assert(WIFEXITED(status))

                let exitCode = WEXITSTATUS(status)
                if exitCode == EXIT_SUCCESS {
                    DDLogInfo("Process \(pid) exited successfully", ddlog: ddlog)
                } else {
                    DDLogWarn("Process \(pid) exited with code \(exitCode)", ddlog: ddlog)
                }

                terminationReason = .exit(exitCode)
            }

            // by using exactly method, we won't crash it!
            let receipt = ExecuteReceipt(
                terminationReason: terminationReason,
                pid: Int(exactly: pid) ?? -1,
                wait: Int(exactly: wait) ?? -1,
                error: isTimeout ? .timeout : nil,
                stdout: stdoutStr,
                stderr: stderrStr
            )
            completionBlock?(receipt)
        }
        processSource.resume()

        // timeout control
        timerSource.schedule(deadline: wallTimeout)
        timerSource.resume()
    }
}
