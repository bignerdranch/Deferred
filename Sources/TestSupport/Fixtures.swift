//
//  Fixtures.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Deferred
#if SWIFT_PACKAGE
import Result
import Task
#endif

import Dispatch
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

enum TestError: Error {
    case first
    case second
    case third
}

func sleep(_ duration: DispatchTimeInterval) {
    var t = timespec(tv_sec: 0, tv_nsec: 0)
    switch duration {
    case .microseconds(let micro):
        t.tv_nsec = micro * 1_000
    case .nanoseconds(let nano):
        t.tv_nsec = nano
    case .milliseconds(let millo):
        t.tv_nsec = millo * 1_000
    case .seconds(let sec):
        t.tv_sec = sec
    }
    nanosleep(&t, nil)
}

extension XCTestCase {
    func waitForTaskToComplete<T>(_ task: Task<T>, file: StaticString = #file, line: UInt = #line) -> TaskResult<T> {
        let expectation = self.expectation(description: "task completed")
        var result: TaskResult<T>?
        task.upon(.main) { [weak expectation] in
            result = $0
            expectation?.fulfill()
        }
        waitForExpectations(file: file, line: line)

        return result!
    }

    func waitForExpectations(file: StaticString = #file, line: UInt = #line) {
        let timeout: Double = 10
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            waitForExpectations(timeout: timeout, handler: nil)
        #else
            waitForExpectations(timeout: timeout, file: file, line: line, handler: nil)
        #endif
    }

    func waitForExpectationsShort(file: StaticString = #file, line: UInt = #line) {
        let timeout: Double = 3
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            waitForExpectations(timeout: timeout, handler: nil)
        #else
            waitForExpectations(timeout: timeout, file: file, line: line, handler: nil)
        #endif
    }

    func afterDelay(upon queue: DispatchQueue = .main, execute body: @escaping() -> ()) {
        queue.asyncAfter(deadline: .now() + 0.15, execute: body)
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
