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

let TestTimeout: TimeInterval = 15

enum Error: Swift.Error {
    case first
    case second
    case third
}

func afterDelay(_ delay: TimeInterval, upon queue: DispatchQueue = DispatchQueue.main, perform body: @escaping () -> Void) {
    let delay = DispatchTime.now() + Double(Int64(delay * TimeInterval(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    queue.asyncAfter(deadline: delay, execute: body)
}

extension XCTestCase {
    func waitForTaskToComplete<T>(_ task: Task<T>) -> TaskResult<T> {
        let expectation = self.expectation(description: "task completed")
        var result: TaskResult<T>?
        task.uponMainQueue { [weak expectation] in
            result = $0
            expectation?.fulfill()
        }
        waitForExpectations(timeout: TestTimeout, handler: nil)

        return result!
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
        static let key = DispatchSpecificKey<UnsafeMutableRawPointer!>()
    }

    private(set) var queue: DispatchQueue!
    fileprivate var specificPtr: UnsafeMutableRawPointer!

    override func setUp() {
        super.setUp()

        queue = DispatchQueue(label: "Deferred test queue", attributes: [])
        specificPtr = malloc(0)
        queue.setSpecific(key: Constants.key, value: specificPtr)
    }

    override func tearDown() {
        queue = nil
        free(specificPtr)
        specificPtr = nil

        super.tearDown()
    }

    func assertOnQueue(inFile file: StaticString = #file, atLine line: UInt = #line) {
        XCTAssertEqual(DispatchQueue.getSpecific(key: Constants.key), specificPtr, file: file, line: line)
    }
    
}
