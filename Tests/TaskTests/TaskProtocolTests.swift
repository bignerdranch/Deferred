//
//  TaskProtocolTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/26/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskProtocolTests: XCTestCase {

    func testConditionalFutureInitAmbiguity() {
        // This is a compiler-time check only.
        typealias Result = TaskResult<Int>
        let deferred = Deferred<Result>()
        _ = Future(deferred)
    }

}
