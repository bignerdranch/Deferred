//
//  TaskProgressTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 10/11/18.
//  Copyright © 2018-2019 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

// swiftlint:disable type_body_length

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
class TaskProgressTests: CustomExecutorTestCase {
    static let allTests: [(String, (TaskProgressTests) -> () throws -> Void)] = [
        ("testThatCancellationIsAppliedImmediatelyWhenMapping", testThatCancellationIsAppliedImmediatelyWhenMapping),
        ("testThatTaskCreatedWithProgressReflectsThatProgress", testThatTaskCreatedWithProgressReflectsThatProgress),
        ("testTaskCreatedUnfilledIs0PercentCompleted", testTaskCreatedUnfilledIs0PercentCompleted),
        ("testTaskCreatedFilledIs100PercentCompleted", testTaskCreatedFilledIs100PercentCompleted),
        ("testThatTaskCreatedUnfilledIsNotFinished", testThatTaskCreatedUnfilledIsNotFinished),
        ("testThatTaskWrappingUnfilledIsNotFinished", testThatTaskWrappingUnfilledIsNotFinished),
        ("testThatTaskCreatedFilledIsFinished", testThatTaskCreatedFilledIsFinished),
        ("testThatMapProgressFinishes", testThatMapProgressFinishes),
        ("testThatAndThenProgressFinishes", testThatAndThenProgressFinishes),
        ("testThatChainingWithAThrownErrorFinishes", testThatChainingWithAThrownErrorFinishes),
        ("testThatChainingAFutureIsNotWeighted", testThatChainingAFutureIsNotWeighted),
        ("testThatChainingATaskWithoutCustomProgressIsNotWeighted", testThatChainingATaskWithoutCustomProgressIsNotWeighted),
        ("testThatChainingATaskWithCustomProgressIsWeighted", testThatChainingATaskWithCustomProgressIsWeighted),
        ("testThatChainingWithCustomProgressIsWeighted", testThatChainingWithCustomProgressIsWeighted)
    ]

    func testThatCancellationIsAppliedImmediatelyWhenMapping() {
        let beforeExpect = expectation(description: "original task cancelled")
        let beforeTask = Task<Int>(.never) {
            beforeExpect.fulfill()
        }

        beforeTask.cancel()
        XCTAssert(beforeTask.progress.isCancelled)

        let afterExpect = expectation(description: "filled with same error")
        afterExpect.isInverted = true

        let afterTask = beforeTask.map(upon: customExecutor) { (value) -> String in
            afterExpect.fulfill()
            return String(describing: value)
        }

        XCTAssert(afterTask.progress.isCancelled)

        wait(for: [ beforeExpect, afterExpect ], timeout: shortTimeoutInverted)
    }

    func testThatTaskCreatedWithProgressReflectsThatProgress() {
        let key = ProgressUserInfoKey(rawValue: "Test")

        let progress = Progress(parent: nil, userInfo: nil)
        progress.totalUnitCount = 10
        progress.setUserInfoObject(true, forKey: key)
        progress.isCancellable = false

        let task = Task<Int>(.never, progress: progress)

        XCTAssertEqual(task.progress.fractionCompleted, 0)
        XCTAssertEqual(progress.userInfo[key] as? Bool, true)
        XCTAssert(task.progress.isCancellable)

        progress.completedUnitCount = 5
        XCTAssertEqual(task.progress.fractionCompleted, 0.5, accuracy: 0.001)
    }

    func testTaskCreatedUnfilledIs0PercentCompleted() {
        let incompleteTask = Task<Int>.never
        XCTAssertEqual(incompleteTask.progress.fractionCompleted, 0)
    }

    func testTaskCreatedFilledIs100PercentCompleted() {
        let completedTask = Task(success: 42)
        XCTAssertEqual(completedTask.progress.fractionCompleted, 1)
    }

    func testThatTaskCreatedUnfilledIsNotFinished() {
        let task = Task<Int>.never
        XCTAssertFalse(task.progress.isFinished)
    }

    func testThatTaskWrappingUnfilledIsNotFinished() {
        let deferred = Task<Int>.Promise()
        let wrappedTask = Task(deferred)
        XCTAssertFalse(wrappedTask.progress.isFinished)
    }

    func testThatTaskCreatedFilledIsFinished() {
        let completedTask = Task(success: 42)
        XCTAssert(completedTask.progress.isFinished)
    }

    private func expectation(toFinish progress: Progress) -> XCTestExpectation {
        return XCTKVOExpectation(keyPath: #keyPath(Progress.isFinished), object: progress, expectedValue: true, options: .initial)
    }

    func testThatMapProgressFinishes() {
        let deferred = Task<Int>.Promise()
        let task = deferred.map(upon: customQueue) { $0 * 2 }

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        deferred.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    private func delaySuccessAsFuture<Value>(_ value: @autoclosure @escaping() -> Value) -> Future<Task<Value>.Result> {
        let deferred = Task<Value>.Promise()
        afterShortDelay {
            deferred.succeed(with: value())
        }
        return Future(deferred)
    }

    private func delaySuccessAsTask<Value>(_ value: @autoclosure @escaping() -> Value) -> Task<Value> {
        let promise = Task<Value>.Promise()
        afterShortDelay {
            promise.succeed(with: value())
        }
        return Task(promise)
    }

    func testThatAndThenProgressFinishes() {
        let promise = Task<Int>.Promise()
        let task = promise.andThen(upon: customExecutor) { self.delaySuccessAsFuture($0 * 2) }

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingWithAThrownErrorFinishes() {
        let promise = Task<Int>.Promise()
        let task = promise.andThen(upon: customExecutor) { _ throws -> Task<String> in throw TestError.first }

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    private func expect(fractionIn range: ClosedRange<Double>, from progress: Progress) -> XCTestExpectation {
        let expectation = XCTKVOExpectation(keyPath: #keyPath(Progress.fractionCompleted), object: progress, expectedValue: nil, options: .initial)
        expectation.handler = { object, _ in
            guard let progress = object as? Progress else { return false }
            return range.contains(progress.fractionCompleted)
        }
        return expectation
    }

    func testThatChainingAFutureIsNotWeighted() {
        customQueue.suspend()

        let promise = Task<Int>.Promise()
        let task = promise
            .andThen(upon: .any(), start: { self.delaySuccessAsFuture($0 * 2) })
            .andThen(upon: customQueue, start: { self.delaySuccessAsTask("\($0)") })
            .map(upon: customQueue, transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expect(fractionIn: 0.05 ... 0.25, from: task.progress)
        ], timeout: shortTimeout)

        customQueue.resume()

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingATaskWithoutCustomProgressIsNotWeighted() {
        customQueue.suspend()

        let promise = Task<Int>.Promise()
        let task = Task(promise)
            .andThen(upon: .any(), start: { self.delaySuccessAsFuture($0 * 2) })
            .andThen(upon: customQueue, start: { self.delaySuccessAsTask("\($0)") })
            .map(upon: customQueue, transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expect(fractionIn: 0.05 ... 0.25, from: task.progress)
        ], timeout: shortTimeout)

        customQueue.resume()

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingATaskWithCustomProgressIsWeighted() {
        let promise = Task<Int>.Promise()
        let customProgress = Progress()
        customProgress.totalUnitCount = 5

        let task = Task(promise, progress: customProgress)
            .andThen(upon: .any(), start: { self.delaySuccessAsFuture($0 * 2) })
            .andThen(upon: .any(), start: { self.delaySuccessAsTask("\($0)") })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        customProgress.completedUnitCount = 5

        XCTAssertGreaterThanOrEqual(task.progress.fractionCompleted, 0.5)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingWithCustomProgressIsWeighted() {
        customQueue.suspend()

        let promise1 = Task<Int>.Promise()
        let task = promise1
            .andThen(upon: .any(), start: { [customQueue] (value) -> Task<Int> in
                let promise2 = Task<Int>.Promise()
                let customProgress = Progress()
                customProgress.totalUnitCount = 87135

                customQueue.async {
                    customProgress.completedUnitCount = 10012

                    customQueue.async {
                        customProgress.completedUnitCount = 54442

                        customQueue.async {
                            customProgress.completedUnitCount = 67412

                            customQueue.async {
                                customProgress.completedUnitCount = 87135

                                promise2.succeed(with: value * 2)
                            }
                        }
                    }
                }

                return Task(promise2, progress: customProgress)
            })
            .map(upon: .any(), transform: { "\($0)" })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise1.succeed(with: 9000)

        wait(for: [
            expect(fractionIn: 0.001 ... 0.05, from: task.progress)
        ], timeout: shortTimeout)

        customQueue.resume()

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatMappingWithCustomProgressIsWeighted() {
        let promise1 = Task<Int>.Promise()

        let task = promise1
            .map(upon: .any(), transform: { (value) -> Int in
                XCTAssertNotNil(Progress.current())

                let customProgress = Progress(totalUnitCount: 32)
                customProgress.completedUnitCount = 1
                customProgress.completedUnitCount = 2
                customProgress.completedUnitCount = 4
                customProgress.completedUnitCount = 8
                customProgress.completedUnitCount = 16
                customProgress.completedUnitCount = 32

                return value * 2
            })
            .map(upon: .any(), transform: { "\($0)" })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.fractionCompleted, 0)

        let expectFractionCompletedToChange = XCTKVOExpectation(keyPath: #keyPath(Progress.fractionCompleted), object: task.progress)
        expectFractionCompletedToChange.expectedFulfillmentCount = 9

        promise1.succeed(with: 9000)

        wait(for: [
            expectFractionCompletedToChange,
            expectation(toFinish: task.progress)
        ], timeout: longTimeout)

        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }
}
#endif
