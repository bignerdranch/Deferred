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

    func impossible<T, U>(_ value: T) -> U {
        XCTFail("Unreachable code in test")
        repeat {
            RunLoop.current.run()
        } while true
    }

    @nonobjc var anyUnfinishedTask: (Deferred<Task<Int>.Result>, Task<Int>) {
        let d = Deferred<Task<Int>.Result>()
        return (d, Task(d))
    }

    @nonobjc var anyFinishedTask: Task<Int> { return Task(value: 42) }

    @nonobjc var anyFailedTask: Task<Int> { return Task(error: Error.first) }

    @nonobjc func contrivedNextTask(for result: Int) -> Task<Int> {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: nil)
        afterDelay {
            d.succeed(result * 2)
        }
        return task
    }

}

class TaskTests: XCTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess { _ in expectation.fulfill() }
        task.uponFailure(impossible)

        d.succeed(1)

        waitForExpectations()
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(impossible)
        task.uponFailure { _ in expectation.fulfill() }

        d.fail(Error.first)

        waitForExpectations()
    }

    func testThatMapPassesThroughErrors() {
        let expectation = self.expectation(description: "original task filled")
        let task: Task<String> = anyFailedTask.map(impossible)

        task.upon {
            XCTAssertEqual($0.error as? Error, .first)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = self.expectation(description: "mapped filled with error")
        let task: Task<String> = anyFinishedTask.map { _ in
            throw Error.second
        }

        task.upon {
            XCTAssertEqual($0.error as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap { _ in
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectations()
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap { _ -> Task<String> in
            throw Error.second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverPassesThroughValues() {
        let expectation = self.expectation(description: "mapped filled with same error")
        let task: Task<Int> = anyFinishedTask.recover(impossible)

        task.upon {
            XCTAssertNil($0.error)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverMapsFailures() {
        let expectation = self.expectation(description: "original task filled")
        let task: Task<Int> = anyFailedTask.recover { _ in 42 }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatCancellationIsAppliedImmediatelyWhenMapping() {
        let beforeExpectation = expectation(description: "original task cancelled")
        let beforeTask = Task<Int>(Deferred<TaskResult<Int>>(), cancellation: beforeExpectation.fulfill)

        beforeTask.cancel()
        XCTAssert(beforeTask.progress.isCancelled)

        let afterTask: Task<String> = beforeTask.map(impossible)

        XCTAssert(afterTask.progress.isCancelled)

        waitForExpectations()
    }

    func testThatTaskCreatedWithProgressReflectsThatProgress() {
        let key = ProgressUserInfoKey(rawValue: "Test")

        let progress = Progress(parent: nil, userInfo: nil)
        progress.totalUnitCount = 10
        progress.setUserInfoObject(true, forKey: key)
        progress.isCancellable = false

        let task = Task<Int>(Deferred<TaskResult<Int>>(), progress: progress)

        XCTAssertEqualWithAccuracy(task.progress.fractionCompleted, 0, accuracy: 0.001)
        XCTAssertEqual(progress.userInfo[key] as? Bool, true)
        XCTAssert(task.progress.isCancellable)

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

        XCTAssert(task.progress.isIndeterminate)
    }

    func testThatTaskWrappingUnfilledIsIndeterminate() {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: {})

        XCTAssertFalse(task.progress.isIndeterminate)
    }

    func testThatTaskWrappingFilledIsDeterminate() {
        let d = Deferred<Task<Int>.Result>(value: .success(42))
        let task = Task(d)

        XCTAssertFalse(task.progress.isIndeterminate)
    }

    func testThatMapIncrementsParentProgressFraction() {
        let task = anyFinishedTask.map { $0 * 2 }
        _ = expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress, handler: nil)
        waitForExpectations()
    }

    func testThatFlatMapIncrementsParentProgressFraction() {
        let task = anyFinishedTask.flatMap(contrivedNextTask)
        XCTAssertNotEqual(task.progress.fractionCompleted, 1)

        _ = expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress, handler: nil)
        waitForExpectations()
    }

}

class TaskCustomExecutorTests: CustomExecutorTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(executor) { _ in expectation.fulfill() }
        task.uponFailure(executor, impossible)

        d.succeed(1)

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(executor, impossible)
        task.uponFailure(executor) { _ in expectation.fulfill() }

        d.fail(Error.first)

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = self.expectation(description: "mapped filled with error")
        let task: Task<String> = anyFinishedTask.map(upon: executor) { _ in
            throw Error.second
        }

        task.upon(executor) {
            XCTAssertEqual($0.error as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(2)
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.flatMap(upon: executor) { _ in
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: executor) { _ -> Task<String> in
            throw Error.second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalledAtLeastOnce()
    }

    func testThatRecoverMapsFailures() {
        let expectation = self.expectation(description: "mapped filled with same error")
        let task: Task<Int> = anyFailedTask.recover(upon: executor) { _ in 42 }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(1)
    }

}

class TaskCustomQueueTests: CustomQueueTestCase {

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }
        task.uponFailure(queue, impossible)

        d.succeed(1)

        waitForExpectations()
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(queue, impossible)
        task.uponFailure(queue) { _ in
            self.assertOnQueue()
            expectation.fulfill()
        }

        d.fail(Error.first)

        waitForExpectations()
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = self.expectation(description: "original task filled")
        let task: Task<String> = anyFinishedTask.map(upon: queue) { _ in
            self.assertOnQueue()
            throw Error.second
        }

        task.upon {
            XCTAssertEqual($0.error as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatFlatMapForwardsCancellationToSubsequentTask() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: queue) { _ -> Task<String> in
            self.assertOnQueue()
            return Task(future: Future(), cancellation: expectation.fulfill)
        }

        task.cancel()

        waitForExpectations()
    }

    func testThatThrowingFlatMapSubstitutesWithError() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task = anyFinishedTask.flatMap(upon: queue) { _ -> Task<String> in
            throw Error.second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? Error, .second)
            expectation.fulfill()
        }

        waitForExpectations()
    }

    func testThatRecoverMapsFailures() {
        let expectation = self.expectation(description: "original task filled")
        let task: Task<Int> = anyFailedTask.recover(upon: queue) { _ in
            self.assertOnQueue()
            return 42
        }

        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }

        waitForExpectations()
    }

}
