//
//  Timeout.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/24/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import Dispatch

/// An amount of time to wait for an event.
public enum Timeout {
    /// Do not wait at all.
    case now
    /// Wait indefinitely.
    case forever
    /// Wait for a given number of seconds.
    case interval(Double)
}

extension DispatchTime {

    init(_ timeout: Timeout) {
        switch timeout {
        case .now:
            self = .now()
        case .forever:
            self = .distantFuture
        case .interval(let time):
            self = .now() + time
        }
    }

}
