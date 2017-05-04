//
//  TaskWorkItemTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/15/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class TaskWorkItemTests: XCTestCase {
    static var allTests: [(String, (TaskWorkItemTests) -> () throws -> Void)] {
        return [
            ("testThatCancellingATaskAfterItStartsRunningIsANoop", testThatCancellingATaskAfterItStartsRunningIsANoop),
            ("testThatCancellingBeforeATaskStartsProducesTheCancellationError", testThatCancellingBeforeATaskStartsProducesTheCancellationError),
        ]
    }

    private var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        queue = DispatchQueue(label: "BlockCancellationTestsQueue")
    }

    override func tearDown() {
        queue = nil

        super.tearDown()
    }

    func testThatCancellingATaskAfterItStartsRunningIsANoop() {
        let startSemaphore = DispatchSemaphore(value: 0)
        let finishSemaphore = DispatchSemaphore(value: 0)

        let task = Task<Int>(upon: queue, onCancel: TestError.first) {
            startSemaphore.signal()
            XCTAssertEqual(finishSemaphore.wait(timeout: .distantFuture), .success)
            return 1
        }

        XCTAssertEqual(startSemaphore.wait(timeout: .distantFuture), .success)
        task.cancel()
        finishSemaphore.signal()

        let result = waitForTaskToComplete(task)
        XCTAssertEqual(try? result.extract(), 1)
    }

    func testThatCancellingBeforeATaskStartsProducesTheCancellationError() {
        let semaphore = DispatchSemaphore(value: 0)

        // send a block into queue to keep it blocked while we submit our real test task
        queue.async {
            _ = semaphore.wait(timeout: .distantFuture)
        }

        let task = Task<Int>(upon: queue, onCancel: TestError.second) { 1 }

        task.cancel()

        let result = waitForTaskToComplete(task)
        semaphore.signal()
        XCTAssertEqual(result.error as? TestError, .second)
    }
}
