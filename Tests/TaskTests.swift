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

}

class TaskTests: XCTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess { _ in expectation.fulfill() }
        task.uponFailure(impossible)

        d.succeed(1)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testUponFailure() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(impossible)
        task.uponFailure { _ in expectation.fulfill() }

        d.fail(Error.First)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatMapPassesThroughErrors() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(error: Error.First)

        let afterExpectation = expectationWithDescription("mapped filled with same error")
        let afterTask: Task<String> = beforeTask.map(impossible)

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .First)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .First)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectationWithDescription("mapped filled with error")
        let afterTask: Task<String> = beforeTask.map { _ in
            throw Error.Second
        }

        beforeTask.upon {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap { _ in
            return Task(future: Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap { _ -> Task<String> in
            throw Error.Second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverPassesThroughValues() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(value: 1)

        let afterExpectation = expectationWithDescription("mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(impossible)

        beforeTask.upon {
            XCTAssertEqual($0.value, 1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertNil($0.error)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(error: Error.First)

        let afterExpectation = expectationWithDescription("mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover { _ in 42 }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .First)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
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
        let d = Deferred<Task<Int>.Result>.init(value: .Success(42))
        let task = Task(d, cancellation: {})

        XCTAssertFalse(task.progress.indeterminate)
    }

    func testThatMapExtendsParentFractions() {
        let beforeTask: Task<Int> = Task(value: 42)
        XCTAssertEqualWithAccuracy(beforeTask.progress.fractionCompleted, 1, accuracy: 0.001)

        let afterTask = beforeTask.map { $0 * 2 }
        _ = expectationForPredicate(NSPredicate(block: {
            abs(($0.0 as! NSProgress).fractionCompleted.distanceTo(1)) <= 0.0001
        }), evaluatedWithObject: afterTask.progress, handler: nil)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapExtendsParentFractions() {
        let beforeTask: Task<Int> = Task(value: 42)
        XCTAssertEqualWithAccuracy(beforeTask.progress.fractionCompleted, 1, accuracy: 0.001)

        let afterTask = beforeTask.flatMap { (before) -> Task<Int> in
            let d = Deferred<Task<Int>.Result>()
            let task = Task(d, cancellation: nil)
            afterDelay(0.5, perform: {
                d.succeed(before * 2)
            })
            return task
        }
        XCTAssertNotEqualWithAccuracy(afterTask.progress.fractionCompleted, 1, 0.001)

        _ = expectationForPredicate(NSPredicate(block: {
            abs(($0.0 as! NSProgress).fractionCompleted.distanceTo(1)) <= 0.0001
        }), evaluatedWithObject: afterTask.progress, handler: nil)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

}

class TaskCustomExecutorTests: CustomExecutorTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(executor) { _ in expectation.fulfill() }
        task.uponFailure(executor, body: impossible)

        d.succeed(1)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testUponFailure() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
        let expectation = expectationWithDescription("upon is called")

        task.uponSuccess(executor, body: impossible)
        task.uponFailure(executor) { _ in expectation.fulfill() }

        d.fail(Error.First)

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectationWithDescription("mapped filled with error")
        let afterTask: Task<String> = beforeTask.map(upon: executor) { _ in
            throw Error.Second
        }

        beforeTask.upon(executor) {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon(executor) {
            XCTAssertEqual($0.error as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(3)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask: Task<String> = beforeTask.flatMap(upon: executor) { _ in
            return Task(future: Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(1)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: executor) { _ -> Task<String> in
            throw Error.Second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalledAtLeastOnce()
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(error: Error.First)

        let afterExpectation = expectationWithDescription("mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(upon: executor) { _ in 42 }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .First)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
        assertExecutorCalled(1)
    }

}

class TaskCustomQueueTests: CustomQueueTestCase {

    func testUponSuccess() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
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
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})
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
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(value: -1)

        let afterExpectation = expectationWithDescription("mapped filled with error")
        let afterTask: Task<String> = beforeTask.map(upon: queue) { _ in
            self.assertOnQueue()
            throw Error.Second
        }

        beforeTask.upon {
            XCTAssertEqual($0.value, -1)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.error as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: queue) { _ -> Task<String> in
            self.assertOnQueue()
            return Task(future: Future(), cancellation: afterExpectation.fulfill)
        }

        afterTask.cancel()

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let beforeTask = Task<Int>(value: 1)

        let afterExpectation = expectationWithDescription("flatMapped task is cancelled")
        let afterTask = beforeTask.flatMap(upon: queue) { _ -> Task<String> in
            throw Error.Second
        }

        afterTask.uponFailure {
            XCTAssertEqual($0 as? Error, .Second)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

    func testThatRecoverMapsFailures() {
        let beforeExpectation = expectationWithDescription("original task filled")
        let beforeTask: Task<Int> = Task(error: Error.First)

        let afterExpectation = expectationWithDescription("mapped filled with same error")
        let afterTask: Task<Int> = beforeTask.recover(upon: queue) { _ in
            self.assertOnQueue()
            return 42
        }

        beforeTask.upon {
            XCTAssertEqual($0.error as? Error, .First)
            beforeExpectation.fulfill()
        }

        afterTask.upon {
            XCTAssertEqual($0.value, 42)
            afterExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(TestTimeout, handler: nil)
    }

}
