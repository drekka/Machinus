//
//  File.swift
//  
//
//  Created by Derek Clarkson on 11/12/2022.
//

import Foundation

/// Used to log messages across concurrency domains.
actor LogActor {
    var entries: [String] = []
    func append(_ value: String) {
        entries.append(value)
    }
}

/// Used to flag an event across concurrency domains.
actor FlagActor {
    var flag = false
    func set() {
        flag = true
    }
}

