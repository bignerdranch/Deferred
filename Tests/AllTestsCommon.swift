//
//  AllTestsCommon.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif
import Dispatch

import Deferred

enum TestError: Error {
    case first
    case second
    case third
}

extension XCTestCase {
    func expectation(deallocationOf object: AnyObject) -> XCTestExpectation {
        return expectation(for: NSPredicate(block: { [weak object] (_, _) -> Bool in
            object == nil
        }), evaluatedWith: NSNull(), handler: nil)
    }

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    func shortWait(for expectations: [XCTestExpectation]) {
        let timeout: TimeInterval = expectations.contains(where: { $0.isInverted }) ? 0.5 : expectations.count > 10 ? 10 : 3
        wait(for: expectations, timeout: timeout)
    }
#elseif swift(>=4.1)
    func shortWait(for expectations: [XCTestExpectation], file: StaticString = #file, line: Int = #line) {
        let timeout: TimeInterval = expectations.count > 10 ? 10 : 3
        waitForExpectations(timeout: timeout, file: file, line: line, handler: nil)
    }
#else
    func shortWait(for expectations: [XCTestExpectation], file: StaticString = #file, line: UInt = #line) {
        let timeout: TimeInterval = expectations.count > 10 ? 10 : 3
        waitForExpectations(timeout: timeout, file: file, line: line, handler: nil)
    }
#endif

    func afterShortDelay(upon queue: DispatchQueue = .global(), execute body: @escaping() -> Void) {
        queue.asyncAfter(deadline: .now() + 0.15, execute: body)
    }
}

extension FutureProtocol {
    /// Waits for the value to become determined, then returns it.
    ///
    /// This is equivalent to unwrapping the value of calling
    /// `wait(until: .distantFuture)`, but may be more efficient.
    ///
    /// This getter will unnecessarily block execution. It might be useful for
    /// testing, but otherwise it should be strictly avoided.
    ///
    /// - returns: The determined value.
    var value: Value {
        return wait(until: .distantFuture).unsafelyUnwrapped
    }

    /// Check whether or not the receiver is filled.
    var isFilled: Bool {
        return peek() != nil
    }

    func shortWait() -> Value? {
        return wait(until: .now() + 0.05)
    }
}

class CustomExecutorTestCase: XCTestCase {
    private class CountingExecutor: Executor {
        let submitCount = Protected(initialValue: 0)

        init() {}

        func submit(_ body: @escaping() -> Void) {
            submitCount.withWriteLock { $0 += 1 }
            body()
        }
    }

    private let _executor = CountingExecutor()

    final var executor: Executor {
        return _executor
    }

    final func assertExecutorNeverCalled(file: StaticString = #file, line: UInt = #line) {
        XCTAssert(_executor.submitCount.withReadLock({ $0 == 0 }), "Executor was called unexpectedly", file: file, line: line)
    }

    final func assertExecutorCalled(atLeast times: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(_executor.submitCount.withReadLock({ $0 >= times }), "Executor was not called enough times", file: file, line: line)
    }
}

extension Collection {

    func random() -> Iterator.Element {
        precondition(!isEmpty, "Should not be called on empty collection")
        #if os(Linux)
            let offset = Glibc.random() % numericCast(count)
        #else // arc4random_uniform is also available on BSD and Bionic
            let offset = arc4random_uniform(numericCast(count))
        #endif
        let index = self.index(startIndex, offsetBy: numericCast(offset))
        return self[index]
    }

}
