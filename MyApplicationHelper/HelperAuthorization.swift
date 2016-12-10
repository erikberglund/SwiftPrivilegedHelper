//
//  HelperAuthorization.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Foundation
import ServiceManagement

struct AuthorizationRightKey {
    static let rightName = "authRightName"
    static let rightDefaultRule = "authRightDefault"
    static let rightDescription = "authRightDescription"
}

class HelperAuthorization: NSObject {
    
    func commandInfo() -> Dictionary<String, Any> {

        // Set up the authorization rule
        // The defaultRights can be either a String or a custom dictionary. I'm using a custom dictionary below, if changing to a string constant, you need to change the cast in setupAuthorizationRights, see the mark.
        // List of defaultRights constants: https://developer.apple.com/reference/security/1669767-authorization_services_c/1670045-policy_database_constants?language=objc
        
         let ruleAdminRightsExtended: [String:Any] = [ "class" : "user",
                                                       "group" : "admin",
                                                        // Timeout defines how long the authorization is valid until the user need to authorize again.
                                                        // 0 means authorize every time, and to remove it like this makes it never expire until the AuthorizationRef is destroyed.
                                                        // "timeout" : 0,
                                                       "version" : 1 ]

        // Define all authorization right definitions this application will use.
        // These will be added to the authorization database to then be used by the Security system to verify authorization of each command
        // The format of this dict is:
        //  key == the command selector as string
        //  value == Dictionary containing:
        //    rightName == The name of the authorization right definition
        //    rightDefaultRule == The rule to decide if the user is authorized for this definition
        //    rightName == The Description is the text that will be shown to the user if prompted by the Security system
        
        let sCommandInfo: [String:Dictionary<String,Any>] =
        [
            NSStringFromSelector(#selector(HelperProtocol.runCommandLs(path:authData:reply:))) :
                [AuthorizationRightKey.rightName : "com.github.erikberglund.MyApplication.runCommandLs", AuthorizationRightKey.rightDefaultRule : ruleAdminRightsExtended, AuthorizationRightKey.rightDescription : "MyApplication want's to run the command /bin/ls"]
        ]
        return sCommandInfo
    }
    
    /* 
        Returns the rightName for the selector string passed
     */
    func authorizationRightNameFor(command: String) -> String {
        let commandDict = self.commandInfo()[command] as! Dictionary<String,Any>
        return commandDict[AuthorizationRightKey.rightName] as! String
    }
    
    /* 
        Returns an NSData object containing an empty AuthorizationRef in it's external form, to be passed to the helper
     */
    func authorizeHelper() -> NSData? {

        var status:OSStatus
        var authData:NSData
        var authRef:AuthorizationRef?
        var authRefExtForm:AuthorizationExternalForm = AuthorizationExternalForm.init()
        
        // Create empty AuthorizationRef
        status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if (status != OSStatus(errAuthorizationSuccess)) {
            print("AuthorizationCreate failed.")
            return nil;
        }
        
        // Make an external form of the AuthorizationRef
        status = AuthorizationMakeExternalForm(authRef!, &authRefExtForm)
        if (status != OSStatus(errAuthorizationSuccess)) {
            print("AuthorizationMakeExternalForm failed.")
            return nil;
        }
        
        // Encapsulate the external form AuthorizationRef in an NSData object
        authData = NSData.init(bytes: &authRefExtForm, length:kAuthorizationExternalFormLength)
        
        // Add all or update all required authorization right definitions to the authorization databse
        if ((authRef) != nil) {
            self.setupAuthorizationRights(authRef: authRef!)
        }
        
        return authData;
    }
    
    /*
        Verifies that the passed AuthorizationRef contains authorization for the command to be run. If not ask the user to supply that.
     */
    func checkAuthorization(authData: NSData?, command: String) -> Bool {
        
        var status:OSStatus
        var authRef:AuthorizationRef?
        
        // Verify the passed authData looks reasonable
        if authData?.length == 0 || authData?.length != kAuthorizationExternalFormLength {
            return false
        }
        
        /* 
            Begin ugly workaround
         
            To convert the AuthorizationExternalForm (authData) it requires an UnsafePointer<AuthorizationExternalForm>.
            I haven't found a good way of going from an NSData object to that specific c array, (or tuple as it's represented in Swift).
         
            Therefore this workaround first put all bytes in an array, then convert that array into a tuple.
            That tuple can be used to call AuthorizationExternalForm.init(bytes: )
         
            In Objective-C it's written like this: AuthorizationCreateFromExternalForm(authData.bytes, &authRef);
         */
        
        // Create empty array of correct length
        var array = [Int8](repeating: 0, count: kAuthorizationExternalFormLength)
        
        // Copy all bytes into array
        authData?.getBytes(&array, length:kAuthorizationExternalFormLength * MemoryLayout<AuthorizationExternalForm>.size)
        
        // Create the expected tuple to initialize the AuthorizationExternalForm by assigning each byte one by one...
        let tuple:(Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) = (array[0], array[1], array[2], array[3], array[4], array[5], array[6], array[7], array[8], array[9], array[10], array[11], array[12], array[13], array[14], array[15], array[16], array[17], array[18], array[19], array[20], array[21], array[22], array[23], array[24], array[25], array[26], array[27], array[28], array[29], array[30], array[31])
        
        // Create the AuthorizationExternalForm item by initializing it with the tuple
        var authRefExtForm:AuthorizationExternalForm = AuthorizationExternalForm.init(bytes: tuple)
        
        /*
            End ugly workaround
         */
        
        // Extract the AuthorizationRef from it's external form
        status = AuthorizationCreateFromExternalForm(&authRefExtForm, &authRef)
        if (status == errAuthorizationSuccess) {
            
            // Get the authorization right definition name of the function calling this
            let authName = authorizationRightNameFor(command: command)
            
            // Create an AuthorizationItem using that definition's name
            var authItem = AuthorizationItem(name: (authName as NSString).utf8String!, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
            
            // Create the AuthorizationRights for using the AuthorizationItem
            var authRight:AuthorizationRights = AuthorizationRights(count: 1, items:&authItem)
            
            // MARK: Check if the user is authorized for the AuthorizationRights. If not it might ask the user for their or an admins credentials.
            status = AuthorizationCopyRights(authRef!, &authRight, nil, [ .extendRights, .interactionAllowed ], nil);
            if (status == errAuthorizationSuccess) {
                return true
            }
        }
        
        if (status != errAuthorizationSuccess) {
            let errorMessage = SecCopyErrorMessageString(status, nil)
            
            // This error is not really handled, shoud probably return it to let the caller know it failed.
            // This will not be printed in the Xcode console as this function is called from the helper.
            print(errorMessage ?? "AuthorizationCreateFromExternalForm Unknown Error")
        }
 
        return false
    }
    
    /* 
        Adds or updates all authorization right definitions to the authorization database
     */
    func setupAuthorizationRights(authRef: AuthorizationRef) -> Void {
        
        // Enumerate through all authorization right definitions and check them one by one against the authorization database
        self.enumerateAuthorizationRights(right: {
            rightName, rightDefaultRule, rightDescription in
            
            var status:OSStatus
            var currentRight:CFDictionary?
            
            // Try to get the authorization right definition from the database
            status = AuthorizationRightGet((rightName as NSString).utf8String! , &currentRight)
            if (status == errAuthorizationDenied) {
                
                // If not found, add or update the authorization entry in the database
                // MARK: Change "rightDefaultRule as! CFDictionary" to "rightDefaultRule as! CFString" if changing defaultRule to string
                status = AuthorizationRightSet(authRef, (rightName as NSString).utf8String!, rightDefaultRule as! CFDictionary, rightDescription as CFString, nil, "Common" as CFString)
            }
            
            if (status != errAuthorizationSuccess) {
                let errorMessage = SecCopyErrorMessageString(status, nil)
                
                // This error is not really handled, shoud probably return it to let the caller know it failed.
                // This will not be printed in the Xcode console as this function is called from the helper.
                print(errorMessage ?? "Error adding authorization right: \(rightName)")
            }
        })
    }
    
    /*
        Convenience to enumerate all right definitions by returning each right's name, description and default
     */
    func enumerateAuthorizationRights(right: (_ rightName: String, _ rightDefaultRule: Any, _ rightDescription: String) -> ()) {
        
        // Loop through all authorization right definitions
        for commandInfoDict in self.commandInfo().values {
            
            // FIXME: There is no error handling here, other than returning early if it fails. That should be added to better find possible errors.
            
            guard let commandDict = commandInfoDict as? Dictionary<String, Any> else { return }
            guard let rightName = commandDict[AuthorizationRightKey.rightName] as? String else { return }
            guard let rightDescription = commandDict[AuthorizationRightKey.rightDescription] as? String else { return }
            let rightDefaultRule = commandDict[AuthorizationRightKey.rightDefaultRule] as Any
            
            // Use the supplied block code to return the authorization right definition Name, Default, and Description
            right(rightName, rightDefaultRule, rightDescription)
        }
    }
}
