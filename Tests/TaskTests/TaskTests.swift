//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskTests: CustomExecutorTestCase {
    static let universalTests: [(String, (TaskTests) -> () throws -> Void)] = [
        ("testUponSuccess", testUponSuccess),
        ("testUponFailure", testUponFailure),
        ("testThatThrowingMapSubstitutesWithError", testThatThrowingMapSubstitutesWithError),
        ("testThatAndThenForwardsCancellationToSubsequentTask", testThatAndThenForwardsCancellationToSubsequentTask),
        ("testThatThrowingAndThenSubstitutesWithError", testThatThrowingAndThenSubstitutesWithError),
        ("testThatRecoverMapsFailures", testThatRecoverMapsFailures),
        ("testThatMapPassesThroughErrors", testThatMapPassesThroughErrors),
        ("testThatRecoverPassesThroughValues", testThatRecoverPassesThroughValues),
        ("testThatFallbackProducesANewTask", testThatFallbackProducesANewTask),
        ("testThatFallbackUsingCustomExecutorProducesANewTask", testThatFallbackUsingCustomExecutorProducesANewTask),
        ("testThatFallbackReturnsOriginalSuccessValue", testThatFallbackReturnsOriginalSuccessValue),
        ("testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue", testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue)
    ]

    static var allTests: [(String, (TaskTests) -> () throws -> Void)] {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            return universalTests + [
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
        #else
            return universalTests
        #endif
    }

    private func expectation<T: Equatable>(that task: Task<T>, succeedsWith makeExpected: @autoclosure @escaping() -> T, description: String? = nil) -> XCTestExpectation {
        let expect = expectation(description: description ?? "uponSuccess is called")
        task.uponSuccess(on: executor) { (value) in
            XCTAssertEqual(value, makeExpected())
            expect.fulfill()
        }
        return expect
    }

    private func expectation<T, U: Error & Equatable>(that task: Task<T>, failsWith makeExpected: @autoclosure @escaping() -> U, description: String? = nil) -> XCTestExpectation {
        let expect = expectation(description: description ?? "uponFailure is called")
        task.uponFailure(on: executor) { (error) in
            XCTAssertEqual(error as? U, makeExpected())
            expect.fulfill()
        }
        return expect
    }

    private func makeAnyUnfinishedTask() -> (deferred: Deferred<Task<Int>.Result>, wrappingTask: Task<Int>) {
        let deferred = Deferred<Task<Int>.Result>()
        return (deferred, Task(deferred))
    }

    private  func makeAnyFinishedTask() -> Task<Int> {
        return Task(success: 42)
    }

    private  func makeAnyFailedTask() -> Task<Int> {
        return Task(failure: TestError.first)
    }

    private func makeContrivedNextTask(for result: Int) -> Task<Int> {
        let deferred = Deferred<Task<Int>.Result>()
        let task = Task(deferred)
        afterShortDelay {
            deferred.succeed(with: result * 2)
        }
        return task
    }

    func testUponSuccess() {
        let (deferred, wrappingTask) = makeAnyUnfinishedTask()
        let expect = expectation(that: wrappingTask, succeedsWith: 1)

        deferred.succeed(with: 1)

        shortWait(for: [ expect ])
        assertExecutorCalled(atLeast: 1)
    }

    func testUponFailure() {
        let (deferred, wrappingTask) = makeAnyUnfinishedTask()
        let expect = expectation(that: wrappingTask, failsWith: TestError.first)

        deferred.fail(with: TestError.first)

        shortWait(for: [ expect ])
        assertExecutorCalled(atLeast: 1)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let task: Task<String> = makeAnyFinishedTask().map(upon: executor) { _ in throw TestError.second }
        let expect = expectation(that: task, failsWith: TestError.second, description: "mapped filled with error")

        shortWait(for: [ expect ])
        assertExecutorCalled(atLeast: 2)
    }

    func testThatAndThenForwardsCancellationToSubsequentTask() {
        let expect = expectation(description: "flatMapped task is cancelled")
        let task = makeAnyFinishedTask().andThen(upon: executor) { _ -> Task<String> in
            Task(.never) { expect.fulfill() }
        }

        task.cancel()

        shortWait(for: [ expect ])
        assertExecutorCalled(atLeast: 1)
    }

    func testThatThrowingAndThenSubstitutesWithError() {
        let task = makeAnyFinishedTask().andThen(upon: executor) { _ -> Task<String> in
            throw TestError.second
        }

        shortWait(for: [
            expectation(that: task, failsWith: TestError.second, description: "flatMapped task is cancelled")
        ])

        assertExecutorCalled(atLeast: 1)
    }

    func testThatRecoverMapsFailures() {
        let task = makeAnyFailedTask().recover(upon: executor) { _ -> Int in
            42
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42)
        ])

        assertExecutorCalled(atLeast: 1)
    }

    func testThatMapPassesThroughErrors() {
        let task = makeAnyFailedTask().map(upon: executor) { (value) -> String in
            XCTFail("Map handler should not be called")
            return String(describing: value)
        }

        shortWait(for: [
            expectation(that: task, failsWith: TestError.first, description: "original task filled")
        ])

        assertExecutorCalled(atLeast: 1)
    }

    func testThatRecoverPassesThroughValues() {
        let task = makeAnyFinishedTask().recover(upon: executor) { _ -> Int in
            XCTFail("Recover handler should not be called")
            return -1
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42, description: "filled with same error")
        ])

        assertExecutorCalled(atLeast: 1)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    func testThatCancellationIsAppliedImmediatelyWhenMapping() {
        let beforeExpect = expectation(description: "original task cancelled")
        let beforeTask = Task<Int>(Deferred<Task<Int>.Result>()) {
            beforeExpect.fulfill()
        }

        beforeTask.cancel()
        XCTAssert(beforeTask.progress.isCancelled)

        let afterExpect = expectation(description: "filled with same error")
        afterExpect.isInverted = true

        let afterTask = beforeTask.map(upon: executor) { (value) -> String in
            afterExpect.fulfill()
            return String(describing: value)
        }

        XCTAssert(afterTask.progress.isCancelled)

        shortWait(for: [ beforeExpect, afterExpect ])
        assertExecutorNeverCalled()
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
        XCTAssertEqual(makeAnyUnfinishedTask().1.progress.fractionCompleted, 0)
    }

    func testTaskCreatedFilledIs100PercentCompleted() {
        XCTAssertEqual(makeAnyFinishedTask().progress.fractionCompleted, 1)
    }

    func testThatTaskCreatedUnfilledIsIndeterminate() {
        let task = Task<Int>.never

        XCTAssert(task.progress.isIndeterminate)
    }

    func testThatTaskWrappingUnfilledIsIndeterminate() {
        let deferred = Deferred<Task<Int>.Result>()
        let wrappedTask = Task(deferred)

        XCTAssertFalse(wrappedTask.progress.isIndeterminate)
    }

    func testThatTaskWrappingFilledIsDeterminate() {
        let deferred = Deferred<Task<Int>.Result>(filledWith: .success(42))
        let wrappedTask = Task(deferred)

        XCTAssertFalse(wrappedTask.progress.isIndeterminate)
    }

    func testThatMapIncrementsParentProgressFraction() {
        let task = makeAnyFinishedTask().map(upon: executor) { $0 * 2 }

        shortWait(for: [
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress)
        ])

        assertExecutorCalled(atLeast: 1)
    }

    func testThatAndThenIncrementsParentProgressFraction() {
        let task = makeAnyFinishedTask().andThen(upon: executor, start: makeContrivedNextTask)
        XCTAssertNotEqual(task.progress.fractionCompleted, 1)

        shortWait(for: [
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress)
        ])

        assertExecutorCalled(atLeast: 1)
    }
    #endif

    func testThatFallbackProducesANewTask() {
        let task = makeAnyFailedTask().fallback(upon: queue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42),
            expectQueueToBeEmpty()
        ])
    }

    func testThatFallbackUsingCustomExecutorProducesANewTask() {
        let task = makeAnyFailedTask().fallback(upon: executor) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42),
            expectationThatExecutor(isCalledAtLeast: 1)
        ])
    }

    func testThatFallbackReturnsOriginalSuccessValue() {
        let (deferred, task1) = makeAnyUnfinishedTask()
        let task2 = task1.fallback(upon: queue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        let expect = expectation(that: task2, succeedsWith: 99)
        deferred.succeed(with: 99)

        shortWait(for: [
            expect,
            expectQueueToBeEmpty()
        ])
    }

    func testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue() {
        let (deferred, task1) = makeAnyUnfinishedTask()
        let task2 = task1.fallback(upon: executor) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        let expect = expectation(that: task2, succeedsWith: 99)
        deferred.succeed(with: 99)

        shortWait(for: [
            expect,
            expectationThatExecutor(isCalledAtLeast: 1)
        ])
    }

    func testSimpleFutureCanBeUpgradedToTask() {
        let deferred = Deferred<Int>()

        let task = Task<Int>(succeedsFrom: deferred)
        let expect = expectation(that: task, succeedsWith: 42)

        deferred.fill(with: 42)
        shortWait(for: [ expect ])
    }

}
