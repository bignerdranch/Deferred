//
//  TaskProgressTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 10/11/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
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
        ("testThatChainingAFutureIsWeightedEqually", testThatChainingAFutureIsWeightedEqually),
        ("testThatChainingATaskWithoutCustomProgressIsWeightedEqually", testThatChainingATaskWithoutCustomProgressIsWeightedEqually),
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

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 2)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        deferred.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectCustomQueueToBeEmpty()
        ], timeout: shortTimeout)
    }

    private func delaySuccessAsFuture<Value>(_ value: @autoclosure @escaping() -> Value) -> Future<TaskResult<Value>> {
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

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 2)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 2)
        XCTAssertEqual(task.progress.totalUnitCount, 2)
        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingWithAThrownErrorFinishes() {
        let promise = Task<Int>.Promise()
        let task = promise.andThen(upon: customExecutor) { _ throws -> Task<String> in throw TestError.first }

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 2)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress),
            expectationThatCustomExecutor(isCalledAtLeast: 1)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 2)
        XCTAssertEqual(task.progress.totalUnitCount, 2)
        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingAFutureIsWeightedEqually() {
        let promise = Task<Int>.Promise()
        let task = promise
            .andThen(upon: .any(), start: { self.delaySuccessAsFuture($0 * 2) })
            .andThen(upon: .any(), start: { self.delaySuccessAsTask("\($0)") })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 4)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingATaskWithoutCustomProgressIsWeightedEqually() {
        let promise = Task<Int>.Promise()
        let task = Task(promise)
            .andThen(upon: .any(), start: { self.delaySuccessAsFuture($0 * 2) })
            .andThen(upon: .any(), start: { self.delaySuccessAsTask("\($0)") })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 4)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
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

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 103)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        customProgress.completedUnitCount = 5

        XCTAssertEqual(task.progress.completedUnitCount, 100)
        XCTAssertEqual(task.progress.totalUnitCount, 103)
        XCTAssertGreaterThanOrEqual(task.progress.fractionCompleted, 0.96)

        promise.succeed(with: 9000)

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 103)
        XCTAssertEqual(task.progress.totalUnitCount, 103)
        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatChainingWithCustomProgressIsWeighted() {
        let promise1 = Task<Int>.Promise()
        let customQueue2 = DispatchQueue(label: "\(type(of: self)).\(#function)")
        customQueue2.suspend()

        let task = promise1
            .andThen(upon: .any(), start: { (value) -> Task<Int> in
                let promise2 = Task<Int>.Promise()
                let customProgress = Progress()
                customProgress.totalUnitCount = 87135

                customQueue2.async {
                    customProgress.completedUnitCount = 10012

                    customQueue2.async {
                        customProgress.completedUnitCount = 54442

                        customQueue2.async {
                            customProgress.completedUnitCount = 67412

                            customQueue2.async {
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

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise1.succeed(with: 9000)

        wait(for: [
            XCTKVOExpectation(keyPath: #keyPath(Progress.totalUnitCount), object: task.progress, expectedValue: 103, options: .initial)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 1)
        XCTAssertLessThanOrEqual(task.progress.fractionCompleted, 0.01)

        customQueue2.resume()

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 103)
        XCTAssertEqual(task.progress.totalUnitCount, 103)
        XCTAssertEqual(task.progress.fractionCompleted, 1)
    }

    func testThatMappingWithCustomProgressIsWeighted() {
        let promise1 = Task<Int>.Promise()
        let expect = expectation(description: "map handler has started executing")

        let task = promise1
            .map(upon: .any(), transform: { (value) -> Int in
                XCTAssertNotNil(Progress.current())

                let customProgress = Progress(totalUnitCount: 32)
                expect.fulfill()

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

        XCTAssertEqual(task.progress.completedUnitCount, 0)
        XCTAssertEqual(task.progress.totalUnitCount, 4)
        XCTAssertEqual(task.progress.fractionCompleted, 0)

        promise1.succeed(with: 9000)

        wait(for: [ expect ], timeout: shortTimeout)

        XCTAssertEqual(task.progress.totalUnitCount, 103)

        wait(for: [
            expectation(toFinish: task.progress)
        ], timeout: longTimeout)

        XCTAssertEqual(task.progress.completedUnitCount, 103)
        XCTAssertEqual(task.progress.totalUnitCount, 103)
    }
}
#endif
