//
//  Fixtures.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred
#if SWIFT_PACKAGE
import Result
#endif

enum Error: Swift.Error {
    case first
    case second
    case third
}

extension XCTestCase {
    func waitForTaskToComplete<T>(_ task: Task<T>) -> TaskResult<T> {
        let expectation = self.expectation(description: "task completed")
        var result: TaskResult<T>?
        task.upon(.main) { [weak expectation] in
            result = $0
            expectation?.fulfill()
        }
        waitForExpectations()

        return result!
    }

    func waitForExpectations() {
        waitForExpectations(timeout: 10, handler: nil)
    }

    func waitForExpectationsShort() {
        waitForExpectations(timeout: 2, handler: nil)
    }

    func afterDelay(upon queue: DispatchQueue = .main, execute body: @escaping() -> ()) {
        queue.asyncAfter(deadline: .now() + 0.1, execute: body)
    }
}

extension FutureProtocol {
    func waitShort() -> Value? {
        return wait(until: .now() + 0.05)
    }
}

extension Either {
    var value: Right? {
        return withValues(ifLeft: { _ in nil }, ifRight: { $0 })
    }

    var error: Left? {
        return withValues(ifLeft: { $0 }, ifRight: { _ in nil })
    }
}

class CustomExecutorTestCase: XCTestCase {
    private struct CountingExecutor: Executor {

        unowned let owner: CustomExecutorTestCase

        func submit(_ body: @escaping() -> Void) {
            owner.submitCount.withWriteLock { (count: inout Int) in
                count += 1
            }

            body()
        }

    }

    private var submitCount = Protected(initialValue: 0)
    final var executor: Executor {
        return CountingExecutor(owner: self)
    }

    func assertExecutorCalled(_ times: Int, inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 == times }), "Executor was not called exactly \(times) times")
    }

    func assertExecutorCalled(atLeast times: Int, inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 >= times }), "Executor was never called", file: file, line: line)
    }
}
