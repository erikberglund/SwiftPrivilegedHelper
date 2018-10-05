//
//  HelperAuthorizationRight.swift
//  SwiftPrivilegedHelper
//
//  Created by Erik Berglund on 2018-10-01.
//  Copyright © 2018 Erik Berglund. All rights reserved.
//

import Foundation

struct HelperAuthorizationRight {

    let command: Selector
    let name: String
    let description: String
    let rule: [String: Any]

    static let ruleDefault: [String: Any] = [
        kAuthorizationRightKeyClass   : "user",
        kAuthorizationRightKeyGroup   : "admin",
        kAuthorizationRightKeyTimeout : 0,
        kAuthorizationRightKeyVersion : 1
    ]

    init(command: Selector, name: String? = nil, description: String, rule: [String: Any]? = nil) {
        self.command = command
        self.name = name ?? HelperConstants.machServiceName + "." + command.description
        self.description = description
        self.rule = rule ?? HelperAuthorizationRight.ruleDefault
    }
}
