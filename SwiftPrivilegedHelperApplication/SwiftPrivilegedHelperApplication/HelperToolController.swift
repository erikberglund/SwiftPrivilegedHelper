//
//  HelperToolController.swift
//  SwiftPrivilegedHelperApplication
//
//  Created by Chip Jarred on 1/21/23.
//  Copyright © 2023 Erik Berglund. All rights reserved.
//

import Foundation
import ServiceManagement

// -------------------------------------
class HelperToolController: NSObject, HelperToolControllerProtocol
{
    // -------------------------------------
    struct HelperControllerError: Error
    {
        var error: Error
        var text: String?
        
        // -------------------------------------
        var localizedDescription: String
        {
            if let text = self.text {
                return "\(text) with error: \(error)"
            }
            else {
                return "Error: \(error)"
            }
        }
        
        init(error: Error, text: String? = nil) {
            self.error = error
            self.text  = text
        }
    }
    
    public private(set) var toolName: String
    private var currentHelperConnection: NSXPCConnection? = nil
    
    var logStdOut: ((String) -> Void)? = nil
    var logStdErr: ((String) -> Void)? = nil
    
    // -------------------------------------
    init(toolName: String) throws
    {
        self.toolName = toolName
        
        /*
         Update the current authorization database right
         
         This will prmpt the user for authentication if something needs
         updating.
         */
        do { try HelperAuthorization.authorizationRightsUpdateDatabase() }
        catch
        {
            throw HelperControllerError(
                error: error,
                text: "Failed to update the authorization database rights"
            )
        }
    }
    
    // -------------------------------------
    func helperStatus(completion: @escaping(_ installed: Bool) -> Void)
    {
        // Compare the CFBundleShortVersionString from the Info.plist in the helper inside our application bundle with the one on disk.

        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + HelperConstants.machServiceName)
        
        guard let helperBundleInfo =
                CFBundleCopyInfoDictionaryForURL(
                    helperURL as CFURL
                ) as? [String: Any],
            let helperVersion =
                helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper(completion)
        else
        {
                completion(false)
                return
        }

        helper.getVersion { installedHelperVersion in
            completion(installedHelperVersion == helperVersion)
        }
   }
    
    // -------------------------------------
    func helper(_ completion: ((Bool) -> Void)?) -> HelperProtocol?
    {
        /*
         Get the current helper connection and return the remote object
         (Helper.swift) as a proxy object to call functions on.
         */
        func localErrorHandler(_ error: Error)
        {
            self.log(
                stdErr: "Helper connection was closed with error: \(error)"
            )
            if let onCompletion = completion {
                onCompletion(false)
            }
        }
        
        return self.helperConnection()?.remoteObjectProxyWithErrorHandler(
            localErrorHandler
        ) as? HelperProtocol
    }
    
    // -------------------------------------
    func install() throws -> Bool
    {
        // Install and activate the helper inside our application bundle to disk.

        var cfError: Unmanaged<CFError>?
        return try kSMRightBlessPrivilegedHelper.withCString
        {
            var authItem = AuthorizationItem(name: $0, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
            return try withUnsafeMutablePointer(to: &authItem)
            {
                var authRights = AuthorizationRights(count: 1, items: $0)

                guard let authRef = try HelperAuthorization.authorizationRef(
                        &authRights,
                        nil,
                        [.interactionAllowed, .extendRights, .preAuthorize]
                    ),
                    SMJobBless(
                        kSMDomainSystemLaunchd,
                        toolName as CFString,
                        authRef, &cfError
                    )
                else
                {
                    if let error = cfError?.takeRetainedValue() {
                        throw error
                    }
                    return false
                }

                self.currentHelperConnection?.invalidate()
                self.currentHelperConnection = nil

                return true
            }
        }
    }
    
    // -------------------------------------
    func withAuthorizedHelper(
        cachedAuthentication: NSData?,
        do block: (HelperProtocol, NSData) throws -> Void) throws
    {
        guard let helper = helper(nil) else {
            return
        }
        
        guard let authData = try cachedAuthentication
                ?? HelperAuthorization.emptyAuthorizationExternalFormData()
        else
        {
            log(stdErr: "Failed to get the empty authorization external form")
            throw HelperAuthorizationError(
                authorizationError: errAuthorizationInternal
            )
        }

        try block(helper, authData)
    }
    
    // MARK:- Helper Connection Methods
    // -------------------------------------
    func helperConnection() -> NSXPCConnection? {
        guard self.currentHelperConnection == nil else {
            return self.currentHelperConnection
        }

        let connection = NSXPCConnection(
            machServiceName: toolName,
            options: .privileged
        )
        connection.exportedInterface = NSXPCInterface(with: HelperToolControllerProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface =
            NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler =
        {
            self.currentHelperConnection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self.currentHelperConnection = nil
            }
        }

        self.currentHelperConnection = connection
        self.currentHelperConnection?.resume()

        return self.currentHelperConnection
    }
    
    // MARK:- HelperToolControllerProtocol Methods
    // -------------------------------------
    func log(stdOut s: String)
    {
        guard !s.isEmpty else { return }
        DispatchQueue.main.async
        {
            if let logger = self.logStdOut
            {
                #if DEBUG
                print(s)
                #endif
                logger(s)
            }
            else { print(s) }
        }
    }

    // -------------------------------------
    func log(stdErr s: String)
    {
        guard !s.isEmpty else { return }
        DispatchQueue.main.async
        {
            if let logger = self.logStdErr
            {
                #if DEBUG
                print(s)
                #endif
                logger(s)
            }
            else { print(s) }
        }
    }
}
