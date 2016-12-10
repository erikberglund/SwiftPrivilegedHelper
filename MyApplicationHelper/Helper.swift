//
//  Helper.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Foundation

class Helper: NSObject, HelperProtocol, NSXPCListenerDelegate{
    
    private var connections = [NSXPCConnection]()
    private var listener:NSXPCListener
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    
    override init(){
        self.listener = NSXPCListener(machServiceName:HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }
    
    /* 
        Starts the helper tool
     */
    func run(){
        self.listener.resume()
        
        // Kepp the helper running until shouldQuit variable is set to true.
        // This variable is changed to true in the connection invalidation handler in the listener(_ listener:shoudlAcceptNewConnection:) funciton.
        while !shouldQuit {
            RunLoop.current.run(until: Date.init(timeIntervalSinceNow: shouldQuitCheckInterval))
        }
    }
    
    /*
        Called when the application connects to the helper
     */
    func listener(_ listener:NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        
        // MARK: Here a check should be added to verify the application that is calling the helper
        // For example, checking that the codesigning is equal on the calling binary as this helper.
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProcessProtocol.self)
        newConnection.exportedInterface = NSXPCInterface(with:HelperProtocol.self)
        newConnection.exportedObject = self;
        newConnection.invalidationHandler = (() -> Void)? {
            if let indexValue = self.connections.index(of: newConnection) {
                self.connections.remove(at: indexValue)
            }
            
            if self.connections.count == 0 {
                self.shouldQuit = true
            }
        }
        self.connections.append(newConnection)
        newConnection.resume()
        return true
    }
    
    /*
        Return bundle version for this helper
     */
    func getVersion(reply: (String) -> Void) {
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)
    }
    
    /*
        Functions to run from the main app
     */
    func runCommandLs(path: String, reply: @escaping (NSNumber) -> Void) {
        
        // For security reasons, all commands should be hardcoded in the helper
        let command = "/bin/ls"
        let arguments = [path]
        
        // Run the task
        runTask(command: command, arguments: arguments, reply:reply)
    }
    
    func runCommandLs(path: String, authData: NSData?, reply: @escaping (NSNumber) -> Void) {
        
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication.
        if !HelperAuthorization().checkAuthorization(authData: authData, command: NSStringFromSelector(#selector(HelperProtocol.runCommandLs(path:authData:reply:)))) {
            return reply(-1)
        }
        
        // For security reasons, all commands should be hardcoded in the helper
        let command = "/bin/ls"
        let arguments = [path]
        
        // Run the task
        runTask(command: command, arguments: arguments, reply:reply)
    }
    
    /*
        Not really used in this test app, but there might be reasons to support multiple simultaneous connections.
     */
    private func connection() -> NSXPCConnection
    {
        //
        return self.connections.last!
    }
    
    
    /*
        General private function to run an external command
     */
    private func runTask(command: String, arguments: Array<String>, reply:@escaping ((NSNumber) -> Void)) -> Void
    {
        let task:Process = Process()
        let stdOut:Pipe = Pipe()
        
        let stdOutHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection().remoteObjectProxy as? ProcessProtocol {
                remoteObject.log(stdOut: output as String)
            }
        }
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler
        
        let stdErr:Pipe = Pipe()
        let stdErrHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection().remoteObjectProxy as? ProcessProtocol {
                remoteObject.log(stdErr: output as String)
            }
        }
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler
        
        task.launchPath = command
        task.arguments = arguments
        task.standardOutput = stdOut
        task.standardError = stdErr
        
        task.terminationHandler = { task in
            reply(NSNumber(value: task.terminationStatus))
        }
        
        task.launch()
    }
}
