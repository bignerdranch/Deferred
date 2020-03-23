//
//  TaskTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/1/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Deferred
#if SWIFT_PACKAGE
import Task
#endif

// swiftlint:disable type_body_length

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
        task.uponSuccess(on: customExecutor) { (value) in
            XCTAssertEqual(value, makeExpected())
            expect.fulfill()
        }
        return expect
    }

    private func expectation<T, U: Error & Equatable>(that task: Task<T>, failsWith makeExpected: @autoclosure @escaping() -> U, description: String? = nil) -> XCTestExpectation {
        let expect = expectation(description: description ?? "uponFailure is called")
        task.uponFailure(on: customExecutor) { (error) in
            XCTAssertEqual(error as? U, makeExpected())
            expect.fulfill()
        }
        return expect
    }

    private func makeAnyUnfinishedTask() -> (deferred: Deferred<Task<Int>.Result>, wrappingTask: Task<Int>) {
        let deferred = Deferred<Task<Int>.Result>()
        return (deferred, deferred.eraseToTask())
    }

    private  func makeAnyFinishedTask() -> Task<Int> {
        return Task(success: 42)
    }

    private  func makeAnyFailedTask() -> Task<Int> {
        return Task(failure: TestError.first)
    }

    private func makeContrivedNextTask(for result: Int) -> Task<Int> {
        let deferred = Deferred<Task<Int>.Result>()
        afterShortDelay {
            deferred.succeed(with: result * 2)
        }
        return deferred.eraseToTask()
    }

    func testUponSuccess() {
        let (deferred, wrappingTask) = makeAnyUnfinishedTask()
        let expect = expectation(that: wrappingTask, succeedsWith: 1)

        deferred.succeed(with: 1)

        wait(for: [
            expect,
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testUponFailure() {
        let (deferred, wrappingTask) = makeAnyUnfinishedTask()
        let expect = expectation(that: wrappingTask, failsWith: TestError.first)

        deferred.fail(with: TestError.first)

        wait(for: [
            expect,
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatThrowingMapSubstitutesWithError() {
        let task: Task<String> = makeAnyFinishedTask().map(upon: customExecutor) { _ in throw TestError.second }
        let expect = expectation(that: task, failsWith: TestError.second, description: "mapped filled with error")

        wait(for: [
            expect,
            expectationThatCustomExecutor(isCalledAtLeast: 2)
        ], timeout: shortTimeout)
    }

    func testThatAndThenForwardsCancellationToSubsequentTask() {
        let expect = expectation(description: "flatMapped task is cancelled")
        let task = makeAnyFinishedTask().andThen(upon: customExecutor) { _ -> Task<String> in
            Task(.never) { expect.fulfill() }
        }

        task.cancel()

        wait(for: [
            expect,
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatThrowingAndThenSubstitutesWithError() {
        let task = makeAnyFinishedTask().andThen(upon: customExecutor) { _ -> Task<String> in
            throw TestError.second
        }

        wait(for: [
            expectation(that: task, failsWith: TestError.second, description: "flatMapped task is cancelled"),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatRecoverMapsFailures() {
        let task = makeAnyFailedTask().recover(upon: customExecutor) { _ -> Int in
            42
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatMapPassesThroughErrors() {
        let task = makeAnyFailedTask().map(upon: customExecutor) { (value) -> String in
            XCTFail("Map handler should not be called")
            return String(describing: value)
        }

        wait(for: [
            expectation(that: task, failsWith: TestError.first, description: "original task filled"),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatRecoverPassesThroughValues() {
        let task = makeAnyFinishedTask().recover(upon: customExecutor) { _ -> Int in
            XCTFail("Recover handler should not be called")
            return -1
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42, description: "filled with same error"),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatFallbackProducesANewTask() {
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    func testThatFallbackUsingCustomExecutorProducesANewTask() {
        let task = makeAnyFailedTask().fallback(upon: customExecutor) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatFallbackReturnsOriginalSuccessValue() {
        let (deferred, task1) = makeAnyUnfinishedTask()
        let task2 = task1.fallback(upon: customQueue) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        let expect = expectation(that: task2, succeedsWith: 99)
        deferred.succeed(with: 99)

        wait(for: [
            expect,
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    func testThatFallbackUsingCustomExecutorReturnsOriginalSuccessValue() {
        let (deferred, task1) = makeAnyUnfinishedTask()
        let task2 = task1.fallback(upon: customExecutor) { _ -> Task<Int> in
            return self.makeAnyFinishedTask()
        }

        let expect = expectation(that: task2, succeedsWith: 99)
        deferred.succeed(with: 99)

        wait(for: [
            expect,
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)
    }

    func testThatFallbackForwardsCancellationToSubsequentTask() {
        let cancelToBeCalled = expectation(description: "flatMapped task is cancelled")
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in
            Task(.never) { cancelToBeCalled.fulfill() }
        }

        task.cancel()

        wait(for: [
            cancelToBeCalled,
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    func testThatFallbackSubstitutesThrownError() {
        let task = makeAnyFailedTask().fallback(upon: customQueue) { _ -> Task<Int> in throw TestError.third }

        wait(for: [
            expectation(that: task, failsWith: TestError.third),
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    func testSimpleFutureCanBeUpgradedToTask() {
        let deferred = Deferred<Int>()

        let task = Task<Int>(succeedsFrom: deferred)
        let expect = expectation(that: task, succeedsWith: 42)

        deferred.fill(with: 42)
        wait(for: [ expect ], timeout: shortTimeout)
    }

    func testRepeatPassesThroughInitialSuccess() {
        let repeatCalledExpectation = XCTestExpectation(description: "repeat closure was called")

        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            repeatCalledExpectation.fulfill()
            return self.makeAnyFinishedTask()
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty(),
            repeatCalledExpectation
        ], timeout: shortTimeout)
    }

    func testRepeatStartsTaskManyTimesForFailure() {
        let repeatCalledExpectation = XCTestExpectation(description: "repeat closure was called")
        repeatCalledExpectation.expectedFulfillmentCount = 4

        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            repeatCalledExpectation.fulfill()
            return self.makeAnyFailedTask()
        }

        wait(for: [
            expectation(that: task, failsWith: TestError.first),
            expectCustomQueueToBeEmpty(),
            repeatCalledExpectation
        ], timeout: shortTimeout)
    }

    func testRepeatPassesThroughSuccessFromRetry() {
        let repeatCalledExpectation = XCTestExpectation(description: "repeat closure was called")
        repeatCalledExpectation.expectedFulfillmentCount = 2

        let shouldSucceedSemaphore = DispatchSemaphore(value: 0)

        let task = Task<Int>.repeat(upon: customQueue, count: 3) {
            repeatCalledExpectation.fulfill()

            if shouldSucceedSemaphore.wait(timeout: .now()) == .timedOut {
                shouldSucceedSemaphore.signal()
                return self.makeAnyFailedTask()
            } else {
                return self.makeAnyFinishedTask()
            }
        }

        wait(for: [
            expectation(that: task, succeedsWith: 42),
            expectCustomQueueToBeEmpty(),
            repeatCalledExpectation
        ], timeout: shortTimeout)
    }

    func testRepeatPassesThroughFailureForContinuation() {
        let repeatCalledExpectation = XCTestExpectation(description: "repeat closure was called")

        let task = Task<Int>.repeat(upon: customQueue, count: 3, continuingIf: { _ in false }, to: {
            repeatCalledExpectation.fulfill()
            return self.makeAnyFailedTask()
        })

        wait(for: [
            expectation(that: task, failsWith: TestError.first),
            expectCustomQueueToBeEmpty(),
            repeatCalledExpectation
        ], timeout: shortTimeout)
    }
}
