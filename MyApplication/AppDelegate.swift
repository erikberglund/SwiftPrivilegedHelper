//
//  AppDelegate.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Cocoa
import ServiceManagement

/*
    Extension to append text to the TextView
 */
extension NSTextView {
    func appendText(line: String) {
        DispatchQueue.main.async {
            let attrDict = [NSFontAttributeName: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize())]
            let astring = NSAttributedString(string: "\(line)\n", attributes: attrDict)
            self.textStorage?.append(astring)
            let loc = self.string?.lengthOfBytes(using: String.Encoding.utf8)
            let range = NSRange(location: loc!, length: 0)
            self.scrollRangeToVisible(range)
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, ProcessProtocol, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var textFieldPath: NSTextField!
    @IBOutlet var textViewOutput: NSTextView!

    var xpcHelperConnection: NSXPCConnection?
    var cachedHelperAuthData: NSData?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Add a default path to lookup
        self.textFieldPath.stringValue = "/var/db/sudo"
        
        // Check if the application can connect to the helper, or if the helper has to be updated with a newer version.
        // If the helper should be updated or installed, prompt the user to do so
        shouldInstallHelper(callback: {
            installed in
            if !installed {
                self.installHelper()
            }
        })
    }
    
    /*
        IBActions
     */
    
    @IBAction func checkWithAuthorization(_ sender: Any) {
        
        // Verify the user input is valid
        guard let path = inputPath() else { return }
        
        // Cache the helper auth data so that the authref can be reused
        if self.cachedHelperAuthData == nil {
            self.cachedHelperAuthData = HelperAuthorization().authorizeHelper()
        }
        
        // Connect to the helper and run the function runCommandLs(path:authData:reply:)
        let xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            print("XPCService error: %@", error)
            } as? HelperProtocol
        
        xpcService?.runCommandLs(path: path, authData: self.cachedHelperAuthData, reply: { (exitStatus) in
            self.textViewOutput.appendText(line: "Command exit status: \(exitStatus)")
        })
 
    }
    
    @IBAction func checkWithoutAuthorization(_ sender: Any) {

        // Verify the user input is valid
        guard let path = inputPath() else { return }
        
        // Connect to the helper and run the function runCommandLs(path:reply:)
        let xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            print("XPCService error: %@", error)
            } as? HelperProtocol
        
        xpcService?.runCommandLs(path:path, reply: { (exitStatus) in
            self.textViewOutput.appendText(line: "Command exit status: \(exitStatus)")
        })
    }
    
    @IBAction func destroyCachedHelperAuthData(_ sender: Any) {
        self.cachedHelperAuthData = nil
    }
    
    
    /*
     
     */
    
    func inputPath() -> String? {
        if self.textFieldPath.stringValue.isEmpty {
            self.textViewOutput.appendText(line: "You need to enter a path to a directory!")
            return nil
        }
        
        let inputURL = URL.init(fileURLWithPath: self.textFieldPath.stringValue)
        do {
            guard try inputURL.checkResourceIsReachable() else { return nil }
        } catch {
            self.textViewOutput.appendText(line: "\(inputURL.path) is not a valid path!")
            return nil
        }
        return inputURL.path
    }
    
    
    func printHelperVersion(){
        let xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            print("XPCService error: %@", error)
            } as? HelperProtocol
        
        xpcService?.getVersion(reply: {
            str in
            print("Helper: Current Version => \(str)")
        })
    }
    
    
    /*
        Install Helper Functions
     */
    
    func shouldInstallHelper(callback: @escaping (Bool) -> Void){
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(HelperConstants.machServiceName)")
        let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL!)
        if helperBundleInfo != nil {
            let helperInfo = helperBundleInfo as! NSDictionary
            let helperVersion = helperInfo["CFBundleVersion"] as! String
            
            print("Helper: Bundle Version => \(helperVersion)")
            
            let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({
                _ in callback(false)
            }) as! HelperProtocol
            
            helper.getVersion(reply: {
                installedVersion in
                print("Helper: Installed Version => \(installedVersion)")
                callback(helperVersion == installedVersion)
            })
        } else {
            callback(false)
        }
    }
    
    // Uses SMJobBless to install or update the helper tool
    func installHelper(){
        
        var authRef:AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights:AuthorizationRights = AuthorizationRights(count: 1, items:&authItem)
        let authFlags: AuthorizationFlags = [ [], .extendRights, .interactionAllowed, .preAuthorize ]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        if (status != errAuthorizationSuccess){
            let error = NSError(domain:NSOSStatusErrorDomain, code:Int(status), userInfo:nil)
            NSLog("Authorization error: \(error)")
        } else {
            var cfError: Unmanaged<CFError>? = nil
            if !SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &cfError) {
                let blessError = cfError!.takeRetainedValue() as Error
                NSLog("Bless Error: \(blessError)")
            } else {
                NSLog("\(HelperConstants.machServiceName) installed successfully")
            }
        }
    }
    
    /*
        Connect Helper Functions
     */
    
    // This could be written as a lazy variable instead to reuse the same connection.
    // But I found an issue when first installing the helper, the connection is invalidated and the never recreated.
    // Therefore I changed that to a function that re-creates a connection if the stored one is invalidated.
    
    // There might be issues with this, It doesn't check if the conenction is suspended for example. That might need to be handled.
    func helperConnection() -> NSXPCConnection? {
        if (self.xpcHelperConnection == nil){
            self.xpcHelperConnection = NSXPCConnection(machServiceName:HelperConstants.machServiceName, options:NSXPCConnection.Options.privileged)
            self.xpcHelperConnection!.exportedObject = self
            self.xpcHelperConnection!.exportedInterface = NSXPCInterface(with:ProcessProtocol.self)
            self.xpcHelperConnection!.remoteObjectInterface = NSXPCInterface(with:HelperProtocol.self)
            self.xpcHelperConnection!.invalidationHandler = {
                self.xpcHelperConnection!.invalidationHandler = nil
                OperationQueue.main.addOperation(){
                    self.xpcHelperConnection = nil
                    NSLog("XPC Connection Invalidated\n")
                }
            }
            self.xpcHelperConnection?.resume()
        }
        return self.xpcHelperConnection
    }
    
    
    /*
        Process Protocol Functions
     */
    
    func log(stdOut: String) -> Void {
        self.textViewOutput.appendText(line: stdOut)
    }
    
    func log(stdErr: String) -> Void {
        self.textViewOutput.appendText(line: stdErr)
    }
    
    
}

