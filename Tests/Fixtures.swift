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
        task.uponMainQueue { [weak expectation] in
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

extension FutureType {
    func waitShort() -> Value? {
        return wait(.interval(0.05))
    }
}

extension ResultType {
    var value: Value? {
        return withValues(ifSuccess: { $0 }, ifFailure: { _ in nil })
    }

    var error: Swift.Error? {
        return withValues(ifSuccess: { _ in nil }, ifFailure: { $0 })
    }
}

class CustomExecutorTestCase: XCTestCase {

    private struct Executor: ExecutorType {

        unowned let owner: CustomExecutorTestCase

        func submit(_ body: @escaping() -> Void) {
            owner.submitCount.withWriteLock { (count: inout Int) in
                count += 1
            }

            body()
        }

    }

    private var submitCount = LockProtected<Int>(item: 0)
    final var executor: ExecutorType {
        return Executor(owner: self)
    }

    func assertExecutorCalled(_ times: Int, inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 == times }), "Executor was not called exactly \(times) times")
    }

    func assertExecutorCalledAtLeastOnce(inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssert(submitCount.withReadLock({ $0 >= 1 }), "Executor was never called", file: file, line: line)
    }
    
}

class CustomQueueTestCase: XCTestCase {

    private struct Constants {
        static let key = DispatchSpecificKey<Unmanaged<CustomQueueTestCase>>()
    }

    private(set) var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        queue = DispatchQueue(label: "Deferred test queue")
        queue.setSpecific(key: Constants.key, value: Unmanaged.passUnretained(self))
    }

    override func tearDown() {
        queue = nil

        super.tearDown()
    }

    func assertOnQueue(inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssertEqual(DispatchQueue.getSpecific(key: Constants.key)?.toOpaque(), Unmanaged.passUnretained(self).toOpaque(), file: file, line: line)
    }
    
}
