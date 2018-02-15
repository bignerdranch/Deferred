//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import class Foundation.RunLoop

#if SWIFT_PACKAGE
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

    @nonobjc var anyFinishedTask: Task<Int> { return Task(success: 42) }

    @nonobjc var anyFailedTask: Task<Int> { return Task(failure: TestError.first) }

    @nonobjc func contrivedNextTask(for result: Int) -> Task<Int> {
        let d = Deferred<Task<Int>.Result>()
        let task = Task(d, cancellation: nil)
        afterDelay {
            d.succeed(with: result * 2)
        }
        return task
    }
}

class TaskTests: CustomExecutorTestCase {
    static var allTests: [(String, (TaskTests) -> () throws -> Void)] {
        let universalTests: [(String, (TaskTests) -> () throws -> Void)] = [
            ("testUponSuccess", testUponSuccess),
            ("testUponFailure", testUponFailure),
            ("testThatThrowingMapSubstitutesWithError", testThatThrowingMapSubstitutesWithError),
            ("testThatAndThenForwardsCancellationToSubsequentTask", testThatAndThenForwardsCancellationToSubsequentTask),
            ("testThatThrowingAndThenSubstitutesWithError", testThatThrowingAndThenSubstitutesWithError),
            ("testThatRecoverMapsFailures", testThatRecoverMapsFailures),
            ("testThatMapPassesThroughErrors", testThatMapPassesThroughErrors),
            ("testThatRecoverPassesThroughValues", testThatRecoverPassesThroughValues),
            ("testThatFallbackAlsoProducesANewTask", testThatFallbackAlsoProducesANewTask)
        ]

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let appleTests: [(String, (TaskTests) -> () throws -> Void)] = [
            ("testThatCancellationIsAppliedImmediatelyWhenMapping", testThatCancellationIsAppliedImmediatelyWhenMapping),
            ("testThatTaskCreatedWithProgressReflectsThatProgress", testThatTaskCreatedWithProgressReflectsThatProgress),
            ("testTaskCreatedUnfilledIs100PercentCompleted", testTaskCreatedUnfilledIs100PercentCompleted),
            ("testTaskCreatedFilledIs100PercentCompleted", testTaskCreatedFilledIs100PercentCompleted),
            ("testThatTaskCreatedUnfilledIsIndeterminate", testThatTaskCreatedUnfilledIsIndeterminate),
            ("testThatTaskWrappingUnfilledIsIndeterminate", testThatTaskWrappingUnfilledIsIndeterminate),
            ("testThatTaskWrappingFilledIsDeterminate", testThatTaskWrappingFilledIsDeterminate),
            ("testThatMapIncrementsParentProgressFraction", testThatMapIncrementsParentProgressFraction),
            ("testThatAndThenIncrementsParentProgressFraction", testThatAndThenIncrementsParentProgressFraction)
        ]

            return universalTests + appleTests
        #else
            return universalTests
        #endif
    }

    func testUponSuccess() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(on: executor) { _ in expectation.fulfill() }
        task.uponFailure(on: executor, execute: impossible)

        d.succeed(with: 1)

        waitForExpectations()
        assertExecutorCalled(atLeast: 1)
    }

    func testUponFailure() {
        let (d, task) = anyUnfinishedTask
        let expectation = self.expectation(description: "upon is called")

        task.uponSuccess(on: executor, execute: impossible)
        task.uponFailure(on: executor) { _ in expectation.fulfill() }

        d.fail(with: TestError.first)

        waitForExpectations()
        assertExecutorCalled(atLeast: 1)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let expectation = self.expectation(description: "mapped filled with error")
        let task: Task<String> = anyFinishedTask.map(upon: executor) { _ in
            throw TestError.second
        }

        task.upon(executor) {
            XCTAssertEqual($0.error as? TestError, .second)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(2)
    }

    func testThatAndThenForwardsCancellationToSubsequentTask() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task: Task<String> = anyFinishedTask.andThen(upon: executor) { _ in
            return Task(future: Future()) {
                expectation.fulfill()
            }
        }

        task.cancel()

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testThatThrowingAndThenSubstitutesWithError() {
        let expectation = self.expectation(description: "flatMapped task is cancelled")
        let task = anyFinishedTask.andThen(upon: executor) { _ -> Task<String> in
            throw TestError.second
        }

        task.uponFailure {
            XCTAssertEqual($0 as? TestError, .second)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(atLeast: 1)
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

    func testThatMapPassesThroughErrors() {
        let expectation = self.expectation(description: "original task filled")
        let task: Task<String> = anyFailedTask.map(upon: executor, transform: impossible)

        task.upon {
            XCTAssertEqual($0.error as? TestError, .first)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testThatRecoverPassesThroughValues() {
        let expectation = self.expectation(description: "mapped filled with same error")
        let task: Task<Int> = anyFinishedTask.recover(upon: executor, substituting: impossible)

        task.upon {
            XCTAssertNil($0.error)
            expectation.fulfill()
        }

        waitForExpectations()
        assertExecutorCalled(1)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    func testThatCancellationIsAppliedImmediatelyWhenMapping() {
        let beforeExpectation = expectation(description: "original task cancelled")
        let beforeTask = Task<Int>(Deferred<Task<Int>.Result>()) {
            beforeExpectation.fulfill()
        }

        beforeTask.cancel()
        XCTAssert(beforeTask.progress.isCancelled)

        let afterTask: Task<String> = beforeTask.map(upon: executor, transform: impossible)

        XCTAssert(afterTask.progress.isCancelled)

        waitForExpectations()
        assertExecutorCalled(0)
    }

    func testThatTaskCreatedWithProgressReflectsThatProgress() {
        let key = ProgressUserInfoKey(rawValue: "Test")

        let progress = Progress(parent: nil, userInfo: nil)
        progress.totalUnitCount = 10
        progress.setUserInfoObject(true, forKey: key)
        progress.isCancellable = false

        let task = Task<Int>(Deferred<Task<Int>.Result>(), progress: progress)

        XCTAssertEqual(task.progress.fractionCompleted, 0, accuracy: 0.001)
        XCTAssertEqual(progress.userInfo[key] as? Bool, true)
        XCTAssert(task.progress.isCancellable)

        progress.completedUnitCount = 5
        XCTAssertEqual(task.progress.fractionCompleted, 0.5, accuracy: 0.001)
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
        let d = Deferred<Task<Int>.Result>(filledWith: .success(42))
        let task = Task(d)

        XCTAssertFalse(task.progress.isIndeterminate)
    }

    func testThatMapIncrementsParentProgressFraction() {
        let task = anyFinishedTask.map(upon: executor) { $0 * 2 }

        _ = expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress, handler: nil)
        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testThatAndThenIncrementsParentProgressFraction() {
        let task = anyFinishedTask.andThen(upon: executor, start: contrivedNextTask)
        XCTAssertNotEqual(task.progress.fractionCompleted, 1)

        _ = expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress, handler: nil)
        waitForExpectations()
        assertExecutorCalled(atLeast: 1)
    }
    
    #endif
    
    func testThatFallbackAlsoProducesANewTask() {
        let expectation = self.expectation(description: "recover produces a new task")
        let task: Task<Int> = anyFailedTask.fallback(upon: executor) { _ in
            return self.anyFinishedTask
        }
        
        task.upon {
            XCTAssertEqual($0.value, 42)
            expectation.fulfill()
        }
        
        waitForExpectations()
        assertExecutorCalled(2)
    }

    func testSimpleFutureCanBeUpgradedToTask() {
        let expectation = self.expectation(description: "original future filled")
        let deferred = Deferred<Int>()
        let task = Task<Int>(success: deferred, cancellation: nil)

        task.uponSuccess { (value) in
            XCTAssertEqual(value, 42)
            expectation.fulfill()
        }

        deferred.fill(with: 42)
        waitForExpectations()
    }

}
