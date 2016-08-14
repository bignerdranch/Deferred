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

class CustomExecutorTestCase: XCTestCase {

    private struct Executor: ExecutorType {

        unowned let owner: CustomExecutorTestCase

        func submit(body: () -> Void) {
            owner.submitCount.withWriteLock { (inout count: Int) in
                count += 1
            }

            body()
        }

    }

    private var submitCount = LockProtected<Int>(item: 0)
    final var executor: ExecutorType {
        return Executor(owner: self)
    }

    func assertExecutorCalled(times: Int, inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 == times }), file: file, line: line, "Executor was not called exactly \(times) times")
    }

    func assertExecutorCalledAtLeastOnce(inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 >= 1 }), file: file, line: line, "Executor was never called")
    }
    
}

class CustomQueueTestCase: XCTestCase {

    private struct Constants {
        static var key = false
    }

    private(set) var queue: dispatch_queue_t!
    private var specificPtr: UnsafeMutablePointer<Void>!

    override func setUp() {
        super.setUp()

        queue = dispatch_queue_create("Deferred test queue", nil)
        specificPtr = malloc(0)
        dispatch_queue_set_specific(queue, &Constants.key, specificPtr, nil)
    }

    override func tearDown() {
        queue = nil
        free(specificPtr)
        specificPtr = nil

        super.tearDown()
    }

    func assertOnQueue(inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssertEqual(dispatch_get_specific(&Constants.key), specificPtr, file: file, line: line)
    }
    
}
