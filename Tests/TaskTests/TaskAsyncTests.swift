//
//  TaskAsyncTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/15/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskAsyncTests: XCTestCase {
    static let allTests: [(String, (TaskAsyncTests) -> () throws -> Void)] = [
        ("testThatCancellingATaskAfterItStartsRunningIsANoop", testThatCancellingATaskAfterItStartsRunningIsANoop),
        ("testThatCancellingBeforeATaskStartsProducesTheCancellationError", testThatCancellingBeforeATaskStartsProducesTheCancellationError)
    ]

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

        let task = Task<Int>.async(upon: queue, onCancel: TestError.first) {
            startSemaphore.signal()
            XCTAssertEqual(finishSemaphore.wait(timeout: .distantFuture), .success)
            return 1
        }

        XCTAssertEqual(startSemaphore.wait(timeout: .distantFuture), .success)
        task.cancel()
        finishSemaphore.signal()

        let expect = expectation(description: "task completed")
        task.uponSuccess(on: .main) { (value) in
            XCTAssertEqual(value, 1)
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }

    func testThatCancellingBeforeATaskStartsProducesTheCancellationError() {
        let semaphore = DispatchSemaphore(value: 0)

        // send a block into queue to keep it blocked while we submit our real test task
        queue.async {
            _ = semaphore.wait(timeout: .distantFuture)
        }

        let task = Task<Int>.async(upon: queue, onCancel: TestError.second) { 1 }

        task.cancel()

        let expect = expectation(description: "task completed")
        task.uponFailure(on: .main) { (error) in
            XCTAssertEqual(error as? TestError, .second)
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }
}
