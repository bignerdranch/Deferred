//
//  BlockCancellationTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/15/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Result
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class BlockCancellationTests: XCTestCase {
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

        let task = Task<Int>(upon: queue, onCancel: Error.first) {
            startSemaphore.signal()
            finishSemaphore.waitShort()
            return 1
        }

        startSemaphore.waitShort()
        task.cancel()
        finishSemaphore.signal()

        let result = waitForTaskToComplete(task)
        XCTAssertEqual(try! result.extract(), 1)
    }

    func testThatCancellingBeforeATaskStartsProducesTheCancellationError() {
        let semaphore = DispatchSemaphore(value: 0)

        // send a block into queue to keep it blocked while we submit our real test task
        queue.async(execute: semaphore.waitShort)

        let task = Task<Int>(upon: queue, onCancel: Error.second) { 1 }

        task.cancel()

        let result = waitForTaskToComplete(task)
        semaphore.signal()
        XCTAssertEqual(result.error as? Error, .second)
    }

}
