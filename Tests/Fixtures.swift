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

func afterDelay(delay: NSTimeInterval, upon queue: dispatch_queue_t = dispatch_get_main_queue(), perform body: () -> Void) {
    let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC)))
    dispatch_after(delay, queue, body)
}

extension XCTestCase {
    func waitForTaskToComplete<T>(task: Task<T>) -> TaskResult<T>! {
        let expectation = expectationWithDescription("task completed")
        var result: TaskResult<T>?
        task.uponMainQueue { [weak expectation] in
            result = $0
            expectation?.fulfill()
        }
        waitForExpectationsWithTimeout(TestTimeout, handler: nil)

        return result
    }
}

extension ResultType {
    var value: Value? {
        return withValues(ifSuccess: { $0 }, ifFailure: { _ in nil })
    }

    var error: ErrorType? {
        return withValues(ifSuccess: { _ in nil }, ifFailure: { $0 })
    }
}
