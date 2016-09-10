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

private extension XCTestCase {

    @noreturn func impossible<T, U>(value: T) -> U {
        XCTFail("Unreachable code in test")
        repeat {
            NSRunLoop.currentRunLoop().run()
        } while true
    }

    @nonobjc var anyUnfinishedTask: (Deferred<Task<Int>.Result>, Task<Int>) {
        let d = Deferred<Task<Int>.Result>()
        return (d, Task(d))
    }

    @nonobjc var anyFinishedTask: Task<Int> { return Task(value: 42) }

    @nonobjc var anyFailedTask: Task<Int> { return Task(error: Error.First) }

    @nonobjc func contrivedNextTask(for result: Int) -> Task<Int> {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: nil)
        afterDelay(0.5, perform: {
            d.succeed(result * 2)
        })
        return task
    }

}

class TaskTests: XCTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess { _ in expectation.fulfill() }
        task.uponFailure(impossible)

        d.succeed(1)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(impossible)
        task.uponFailure { _ in expectation.fulfill() }

        d.fail(Error.First)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatMapPassesThroughErrors() {
        let expectation = expectationWithDescription("mapped filled with same error")
        let task: Task<String> = anyFailedTask.map(impossible)

        task.upon {
            XCTAssertEqual($0.error as? Error, .First)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = expectationWithDescription("mapped filled with error")
        let task: Task<String> = anyFinishedTask.map { _ in
            throw Error.Second
        }

        task.upon {
            XCTAssertEqual($0.error as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap { _ in
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap { _ -> Task<String> in
            throw Error.Second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverPassesThroughValues() {
        let expectation = expectationWithDescription("mapped filled with same error")
        let task: Task<Int> = anyFinishedTask.recover(impossible)

        task.upon {
            XCTAssertNil($0.error)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverMapsFailures() {
        let expectation = expectationWithDescription("mapped filled with same error")
        let task: Task<Int> = anyFailedTask.recover { _ in 42 }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatCancellationIsAppliedImmediatelyWhenMapping() {
        let beforeExpectation = expectationWithDescription("original task cancelled")
        let beforeTask = Task<Int>(Deferred<TaskResult<Int>>(), cancellation: beforeExpectation.fulfill)

        beforeTask.cancel()
        XCTAssert(beforeTask.progress.cancelled)

        let afterTask: Task<String> = beforeTask.map(impossible)

        XCTAssert(afterTask.progress.cancelled)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatTaskCreatedWithProgressReflectsThatProgress() {
        let progress = NSProgress(parent: nil, userInfo: nil)
        progress.totalUnitCount = 10
        progress.setUserInfoObject(true, forKey: "Test")
        progress.cancellable = false

        let task = Task<Int>(Deferred<TaskResult<Int>>(), progress: progress)

        XCTAssertEqualWithAccuracy(task.progress.fractionCompleted, 0, accuracy: 0.001)
        XCTAssertEqual(progress.userInfo["Test"] as? Bool, true)
        XCTAssert(task.progress.cancellable)

        progress.completedUnitCount = 5
        XCTAssertEqualWithAccuracy(task.progress.fractionCompleted, 0.5, accuracy: 0.001)
    }

    func testTaskCreatedUnfilledIs100PercentCompleted() {
        XCTAssertEqual(anyUnfinishedTask.1.progress.fractionCompleted, 0)
    }

    func testTaskCreatedFilledIs100PercentCompleted() {
        XCTAssertEqual(anyFinishedTask.progress.fractionCompleted, 1)
    }

    func testThatTaskCreatedUnfilledIsIndeterminate() {
        let task = Task<Int>()

        XCTAssert(task.progress.indeterminate)
    }

    func testThatTaskWrappingUnfilledIsIndeterminate() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})

        XCTAssertFalse(task.progress.indeterminate)
    }

    func testThatTaskWrappingFilledIsDeterminate() {
        let d = Deferred<Task<Int>.Result>(value: .Success(42))
        let task = Task(d)

        XCTAssertFalse(task.progress.indeterminate)
    }

    func testThatMapIncrementsParentProgressFraction() {
        let task = anyFinishedTask.map { $0 * 2 }
        _ = expectationForPredicate(NSPredicate(format: "fractionCompleted == 1"), evaluatedWithObject: task.progress, handler: nil)
        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapIncrementsParentProgressFraction() {
        let task = anyFinishedTask.flatMap(contrivedNextTask)
        XCTAssertNotEqual(task.progress.fractionCompleted, 1)

        _ = expectationForPredicate(NSPredicate(format: "fractionCompleted == 1"), evaluatedWithObject: task.progress, handler: nil)
        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

}

class TaskCustomExecutorTests: CustomExecutorTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(executor) { _ in expectation.fulfill() }
        task.uponFailure(executor, body: impossible)

        d.succeed(1)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(executor, body: impossible)
        task.uponFailure(executor) { _ in expectation.fulfill() }

        d.fail(Error.First)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = expectationWithDescription("mapped filled with error")
        let task: Task<String> = anyFinishedTask.map(upon: executor) { _ in
            throw Error.Second
        }

        task.upon(executor) {
            XCTAssertEqual($0.error as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(2)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap(upon: executor) { _ in
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(1)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: executor) { _ -> Task<String> in
            throw Error.Second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testThatRecoverMapsFailures() {
        let expectation = expectationWithDescription("mapped filled with same error")
        let task: Task<Int> = anyFailedTask.recover(upon: executor) { _ in 42 }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(1)
    }

}

class TaskCustomQueueTests: CustomQueueTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }
        task.uponFailure(queue, body: impossible)

        d.succeed(1)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(queue, body: impossible)
        task.uponFailure(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }

        d.fail(Error.First)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = expectationWithDescription("mapped filled with error")
        let task: Task<String> = anyFinishedTask.map(upon: queue) { _ in
            self.assertOnQueue()
            throw Error.Second
        }

        task.upon {
            XCTAssertEqual($0.error as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: queue) { _ -> Task<String> in
            self.assertOnQueue()
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = expectationWithDescription("flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: queue) { _ -> Task<String> in
            throw Error.Second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverMapsFailures() {
        let expectation = expectationWithDescription("mapped filled with same error")
        let task: Task<Int> = anyFailedTask.recover(upon: queue) { _ in
            self.assertOnQueue()
            return 42
        }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

}
