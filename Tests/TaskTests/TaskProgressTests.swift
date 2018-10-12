//
//  TaskProgressTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 10/11/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Atomics
import Task
#else
import Deferred
import Deferred.Atomics
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
class TaskProgressTests: CustomExecutorTestCase {
    static let allTests: [(String, (TaskProgressTests) -> () throws -> Void)] = [
        ("testThatCancellationIsAppliedImmediatelyWhenMapping", testThatCancellationIsAppliedImmediatelyWhenMapping),
        ("testThatTaskCreatedWithProgressReflectsThatProgress", testThatTaskCreatedWithProgressReflectsThatProgress),
        ("testTaskCreatedUnfilledIs0PercentCompleted", testTaskCreatedUnfilledIs0PercentCompleted),
        ("testTaskCreatedFilledIs100PercentCompleted", testTaskCreatedFilledIs100PercentCompleted),
        ("testThatTaskCreatedUnfilledIsIndeterminate", testThatTaskCreatedUnfilledIsIndeterminate),
        ("testThatTaskWrappingUnfilledIsIndeterminate", testThatTaskWrappingUnfilledIsIndeterminate),
        ("testThatTaskCreatedFilledIsDeterminate", testThatTaskCreatedFilledIsDeterminate),
        ("testThatMapProgressFinishesAlongsideBaseProgress", testThatMapProgressFinishesAlongsideBaseProgress),
        ("testThatAndThenProgressFinishesAlongsideBaseProgress", testThatAndThenProgressFinishesAlongsideBaseProgress),
        ("testThanMappedProgressTakesUpMajorityOfDerivedProgress", testThanMappedProgressTakesUpMajorityOfDerivedProgress)
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

        let task = Task<Int>(.never, progress: progress)

        XCTAssertEqual(task.progress.fractionCompleted, 0, accuracy: 0.001)
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

    func testThatTaskCreatedUnfilledIsIndeterminate() {
        let task = Task<Int>.never
        XCTAssert(task.progress.isIndeterminate)
    }

    func testThatTaskWrappingUnfilledIsIndeterminate() {
        let deferred = Task<Int>.Promise()
        let wrappedTask = Task(deferred)
        XCTAssertFalse(wrappedTask.progress.isIndeterminate)
    }

    func testThatTaskCreatedFilledIsDeterminate() {
        let completedTask = Task(success: 42)
        XCTAssertFalse(completedTask.progress.isIndeterminate)
    }

    func testThatMapProgressFinishesAlongsideBaseProgress() {
        let deferred = Task<Int>.Promise()
        let task1 = Task(deferred)
        let task2 = task1.map(upon: queue) { $0 * 2 }

        XCTAssertNotEqual(task1.progress.fractionCompleted, 1)
        XCTAssertNotEqual(task2.progress.fractionCompleted, 1)

        deferred.succeed(with: 9000)

        shortWait(for: [
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task1.progress),
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task2.progress),
            expectQueueToBeEmpty()
        ])
    }

    func testThatAndThenProgressFinishesAlongsideBaseProgress() {
        let deferred = Task<Int>.Promise()
        let task1 = Task(deferred)
        let task2 = task1.andThen(upon: executor) { (result) -> Task<Int>.Promise in
            let deferred2 = Task<Int>.Promise()
            self.afterShortDelay {
                deferred2.succeed(with: result * 2)
            }
            return deferred2
        }

        XCTAssertNotEqual(task1.progress.fractionCompleted, 1)
        XCTAssertNotEqual(task2.progress.fractionCompleted, 1)

        deferred.succeed(with: 9000)

        shortWait(for: [
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task1.progress),
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task2.progress)
        ])

        assertExecutorCalled(atLeast: 1)
    }

    func testThanMappedProgressTakesUpMajorityOfDerivedProgress() {
        let customProgress = Progress(totalUnitCount: 5)
        let deferred = Task<Int>.Promise()
        let task = Task(deferred, progress: customProgress)
            .map(upon: .any(), transform: { $0 * 2 })
            .map(upon: .any(), transform: { "\($0)" })
            .map(upon: .any(), transform: { "\($0)\($0)" })

        XCTAssertNotEqual(customProgress.fractionCompleted, 1)
        XCTAssertNotEqual(task.progress.fractionCompleted, 1)

        customProgress.completedUnitCount = 5

        XCTAssertGreaterThanOrEqual(task.progress.fractionCompleted, 0.75)

        deferred.succeed(with: 9000)

        shortWait(for: [
            expectation(for: NSPredicate(format: "fractionCompleted == 1"), evaluatedWith: task.progress)
        ])
    }
}
#endif
