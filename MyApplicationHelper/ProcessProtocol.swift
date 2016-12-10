//
//  ProcessProtocol.swift
//  MyApplication
//
//  Created by Erik Berglund on 2016-12-06.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

import Foundation

// Protocol to list all functions the helper can call in the main application
@objc(ProcessProtocol)
protocol ProcessProtocol {
    func log(stdOut: String) -> Void
    func log(stdErr: String) -> Void
}
