//
//  Helper.swift
//  SwiftPrivilegedHelper
//
//  Created by Erik Berglund on 2018-10-01.
//  Copyright © 2018 Erik Berglund. All rights reserved.
//

import Foundation

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {

    // MARK: -
    // MARK: Private Constant Variables

    private let listener: NSXPCListener

    // MARK: -
    // MARK: Private Variables

    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0

    // MARK: -
    // MARK: Initialization

    override init() {
        self.listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }

    public func run() {
        self.listener.resume()

        // Keep the helper tool running until the variable shouldQuit is set to true.
        // The variable should be changed in the "listener(_ listener:shoudlAcceptNewConnection:)" function.

        while !self.shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: self.shouldQuitCheckInterval))
        }
    }

    // MARK: -
    // MARK: NSXPCListenerDelegate Methods

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {

        // Verify that the calling application is signed using the same code signing certificate as the helper
        guard self.isValid(connection: connection) else {
            return false
        }

        // Set the protocol that the calling application conforms to.
        connection.remoteObjectInterface =
            NSXPCInterface(with: HelperToolControllerProtocol.self)

        // Set the protocol that the helper conforms to.
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self

        // Set the invalidation handler to remove this connection when it's work is completed.
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }

            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }

        self.connections.append(connection)
        connection.resume()

        return true
    }

    // MARK: -
    // MARK: HelperProtocol Methods

    func getVersion(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }
    
    func withAuthorization(
        authData: NSData?,
        forCommand selector: Selector,
        completion: (NSNumber) -> Void,
        doCommand command:() -> Void)
    {
        /*
         Check the passed authorization, if the user need to authenticate to
         use this command the user might be prompted depending on the settings
         and/or cached authentication.
         */
        guard self.verifyAuthorization(authData, forCommand: selector) else {
            completion(kAuthorizationFailedExitCode)
            return
        }

        command()
    }

    func runCommandLs(
        withPath path: String,
        completion: @escaping (NSNumber) -> Void) {

        // For security reasons, all commands should be hardcoded in the helper
        let command = "/bin/ls"
        let arguments = [path]

        // Run the task
        self.runTask(command: command, arguments: arguments, completion: completion)
    }

    let lsSelector =
        #selector(HelperProtocol.runCommandLs(withPath:authData:completion:))
    func runCommandLs(
        withPath path: String,
        authData: NSData?,
        completion: @escaping (NSNumber) -> Void)
    {
        withAuthorization(
            authData: authData,
            forCommand: lsSelector,
            completion: completion)
        {
            self.runCommandLs(withPath: path, completion: completion)
        }
    }
    
    let launchDaemonsURL = URL(
        fileURLWithPath: "/Library/LaunchDaemons",
        isDirectory: true
    )
    let uninstallSelector =
        #selector(HelperProtocol.runCommandUninstall(authData:completion:))
    func runCommandUninstall(completion: @escaping (NSNumber) -> Void)
    {
        let exectablePath = ProcessInfo.processInfo.arguments[0]
        let plistName =
            URL(fileURLWithPath: exectablePath).lastPathComponent + ".plist"
        let plistURL = launchDaemonsURL.appendingPathComponent(plistName)
        let executableURL = URL(fileURLWithPath: exectablePath)
        
        let fm = FileManager.default
        trace("Deleting \(executableURL.path)")
        let execRemoved = removeFile(executableURL, with: fm)
        trace("Deleting \(plistURL.path)")
        let plistRemoved = removeFile(plistURL, with: fm)
        

        let exitCode = execRemoved && plistRemoved ? 0 : -1
        completion(exitCode as NSNumber)
        
        trace("Qutting helper tool")
        shouldQuit = true
    }
    
    private func removeFile(_ url: URL, with fm: FileManager) -> Bool
    {
        do { try fm.removeItem(at: url) }
        catch
        {
            log(
                stdErr: "Failed to remove helper at \(url.path) with "
                    + "error: \(error)"
            )
            return false
        }
        
        return true
    }
    
    func runCommandUninstall(
        authData: NSData?,
        completion: @escaping (NSNumber) -> Void)
    {
        withAuthorization(
            authData: authData,
            forCommand: uninstallSelector,
            completion: completion)
        {
            self.runCommandUninstall(completion: completion)
        }
    }

    // MARK: -
    // MARK: Private Helper Methods

    private func isValid(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }

    private func verifyAuthorization(_ authData: NSData?, forCommand command: Selector) -> Bool {
        do {
            try HelperAuthorization.verifyAuthorization(authData, forCommand: command)
        } catch {
            log(stdErr: "Authentication Error: \(error)")
            return false
        }
        return true
    }

    private func connection() -> NSXPCConnection? {
        return self.connections.last
    }

    private func runTask(command: String, arguments: Array<String>, completion:@escaping ((NSNumber) -> Void)) -> Void {
        let task = Process()
        let stdOut = Pipe()

        let stdOutHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? HelperToolControllerProtocol {
                remoteObject.log(stdOut: output as String)
            }
        }
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler

        let stdErr:Pipe = Pipe()
        let stdErrHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? HelperToolControllerProtocol {
                remoteObject.log(stdErr: output as String)
            }
        }
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler

        task.launchPath = command
        task.arguments = arguments
        task.standardOutput = stdOut
        task.standardError = stdErr

        task.terminationHandler = { task in
            completion(NSNumber(value: task.terminationStatus))
        }

        task.launch()
    }
    
    private var controller: HelperToolControllerProtocol? {
        self.connection()?.remoteObjectProxy as? HelperToolControllerProtocol
    }
    
    private func log(stdOut s: String)
    {
        if let remoteObject = controller {
            remoteObject.log(stdOut: s)
        }
    }
    
    private func log(stdErr s: String)
    {
        if let remoteObject = controller {
            remoteObject.log(stdErr: s)
        }
    }
    
    private func trace(
        _ s: @autoclosure () -> String,
        file: StaticString = #file,
        line: UInt = #line)
    {
        #if DEBUG
        var useFileInfo: Bool { false }
        if useFileInfo {
            log(stdOut: "\(file):\(line): \(s())")
        }
        else {
            log(stdOut: s())
        }
        #endif
    }
}
