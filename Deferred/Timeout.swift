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
    case Now
    /// Wait indefinitely.
    case Forever
    /// Wait for a given number of seconds.
    case Interval(Double)
}

extension Timeout {

    var rawValue: dispatch_time_t {
        switch self {
        case .Now:
            return DISPATCH_TIME_NOW
        case .Forever:
            return DISPATCH_TIME_FOREVER
        case .Interval(let time):
            return dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        }
    }

}
