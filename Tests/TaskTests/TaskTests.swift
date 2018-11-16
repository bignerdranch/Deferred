//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Atomics
import Deferred
import Task
#else
import Deferred
import Deferred.Atomics
#endif

class TaskTests: CustomExecutorTestCase {
    static let allTests: [(String, (TaskTests) -> () throws -> Void)] = [
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
        ("testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue", testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue),
        ("testThatFallbackForwardsCancellationToSubsequentTask", testThatFallbackForwardsCancellationToSubsequentTask),
        ("testThatFallbackSubstitutesThrownError", testThatFallbackSubstitutesThrownError),
        ("testSimpleFutureCanBeUpgradedToTask", testSimpleFutureCanBeUpgradedToTask)
    ]

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

    func testThatFallbackProducesANewTask() {
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty()
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
        let task2 = task1.fallback(upon: customQueue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        let expect = expectation(that: task2, succeedsWith: 99)
        deferred.succeed(with: 99)

        shortWait(for: [
            expect,
            expectCustomQueueToBeEmpty()
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

    func testThatFallbackForwardsCancellationToSubsequentTask() {
        let cancelToBeCalled = expectation(description: "flatMapped task is cancelled")
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in
            Task(.never) { cancelToBeCalled.fulfill() }
        }

        task.cancel()

        shortWait(for: [
            cancelToBeCalled,
            expectCustomQueueToBeEmpty()
        ])
    }

    func testThatFallbackSubstitutesThrownError() {
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in throw TestError.third }

        shortWait(for: [
            expectation(that: task, failsWith: TestError.third),
            expectCustomQueueToBeEmpty()
        ])
    }

    func testSimpleFutureCanBeUpgradedToTask() {
        let deferred = Deferred<Int>()

        let task = Task<Int>(succeedsFrom: deferred)
        let expect = expectation(that: task, succeedsWith: 42)

        deferred.fill(with: 42)
        shortWait(for: [ expect ])
    }

    func testRepeatPassesThroughInitialSuccess() {
        var counter = 0
        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            bnr_atomic_fetch_add(&counter, 1)
            return self.makeAnyFinishedTask()
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty()
        ])

        XCTAssertEqual(bnr_atomic_load(&counter), 1)
    }

    func testRepeatStartsTaskManyTimesForFailure() {
        var counter = 0
        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            bnr_atomic_fetch_add(&counter, 1)
            return self.makeAnyFailedTask()
        }

        shortWait(for: [
            expectation(that: task, failsWith: TestError.first),
            expectCustomQueueToBeEmpty()
        ])

        XCTAssertEqual(bnr_atomic_load(&counter), 4)
    }

    func testRepeatPassesThroughSuccessFromRetry() {
        var counter = 0
        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            return bnr_atomic_fetch_add(&counter, 1) == 1 ? self.makeAnyFinishedTask() : self.makeAnyFailedTask()
        }

        shortWait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty()
        ])

        XCTAssertEqual(bnr_atomic_load(&counter), 2)
    }

    func testRepeatPassesThroughFailureForContinuation() {
        var counter = 0
        let task = Task<Int>.repeat(upon: customQueue, count: 3, continuingIf: { _ in false }, to: {
            bnr_atomic_fetch_add(&counter, 1)
            return self.makeAnyFailedTask()
        })

        shortWait(for: [
            expectation(that: task, failsWith: TestError.first),
            expectCustomQueueToBeEmpty()
        ])

        XCTAssertEqual(bnr_atomic_load(&counter), 1)
    }
}
