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

private var oneSecondTimeout: dispatch_time_t {
    return dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC))
}

class BlockCancellationTests: XCTestCase {
    private var queue: dispatch_queue_t!

    override func setUp() {
        super.setUp()

        queue = dispatch_queue_create("BlockCancellationTestsQueue", DISPATCH_QUEUE_SERIAL)
    }

    override func tearDown() {
        queue = nil

        super.tearDown()
    }

    func testThatCancellingATaskAfterItStartsRunningIsANoop() {
        let startSemaphore = dispatch_semaphore_create(0)
        let finishSemaphore = dispatch_semaphore_create(0)

        let task = Task<Int>(upon: queue, onCancel: Error.First) {
            dispatch_semaphore_signal(startSemaphore)
            dispatch_semaphore_wait(finishSemaphore, oneSecondTimeout)
            return 1
        }

        dispatch_semaphore_wait(startSemaphore, oneSecondTimeout)
        task.cancel()
        dispatch_semaphore_signal(finishSemaphore)

        let result = waitForTaskToComplete(task)
        XCTAssertEqual(try! result.extract(), 1)
    }

    func testThatCancellingBeforeATaskStartsProducesTheCancellationError() {
        let semaphore = dispatch_semaphore_create(0)

        // send a block into queue to keep it blocked while we submit our real test task
        dispatch_async(queue) {
            dispatch_semaphore_wait(semaphore, oneSecondTimeout)
        }

        let task = Task<Int>(upon: queue, onCancel: Error.Second) { 1 }

        task.cancel()
        dispatch_semaphore_signal(semaphore)

        let result = waitForTaskToComplete(task)
        XCTAssertEqual(result.error as? Error, Error.Second)    }

}
