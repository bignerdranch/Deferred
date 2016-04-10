//
//  Fixtures.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred
#if SWIFT_PACKAGE
import Result
#endif

let TestTimeout: NSTimeInterval = 15

enum Error: ErrorType {
    case First
    case Second
    case Third
}

extension ResultType {
    var value: Value? {
        return withValues(ifSuccess: { $0 }, ifFailure: { _ in nil })
    }

    var error: ErrorType? {
        return withValues(ifSuccess: { _ in nil }, ifFailure: { $0 })
    }
}
