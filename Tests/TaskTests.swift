//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Result
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class TaskTests: XCTestCase {

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let firstTask = Task<Int>(value: 1)
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let mappedTask = firstTask.flatMap { _ -> Task<Int> in
            let d = Deferred<TaskResult<Int>>()
            return Task(d, cancellation: expectation.fulfill)
        }
        mappedTask.cancel()
        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

}
