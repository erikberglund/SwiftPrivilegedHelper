//
//  HelperProtocol.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Foundation

struct HelperConstants {
    static let machServiceName = "com.github.erikberglund.MyApplicationHelper"
}

// Protocol to list all functions the main application can call in the helper
@objc(HelperProtocol)
protocol HelperProtocol {
    func getVersion(reply: (String) -> Void)
    func runCommandLs(path: String, reply: @escaping (NSNumber) -> Void)
    func runCommandLs(path: String, authData: NSData?, reply: @escaping (NSNumber) -> Void)
}
