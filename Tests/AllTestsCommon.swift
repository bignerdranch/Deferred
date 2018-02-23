//
//  AllTestsCommon.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2017 Big Nerd Ranch. All rights reserved.
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
    case .never:
        return
    }
    nanosleep(&t, nil)
}

extension XCTestCase {
    func waitForExpectations(file: StaticString = #file, line: Int = #line) {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            waitForExpectations(timeout: 10, handler: nil)
        #else
            waitForExpectations(timeout: 10, file: file, line: numericCast(line), handler: nil)
        #endif
    }

    func waitForExpectationsShort(file: StaticString = #file, line: Int = #line) {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            waitForExpectations(timeout: 3, handler: nil)
        #else
            waitForExpectations(timeout: 3, file: file, line: numericCast(line), handler: nil)
        #endif
    }

    func afterDelay(upon queue: DispatchQueue = .main, execute body: @escaping() -> Void) {
        queue.asyncAfter(deadline: .now() + 0.15, execute: body)
    }
}

extension FutureProtocol {
    func waitShort() -> Value? {
        return wait(until: .now() + 0.05)
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

    func assertExecutorCalled(_ times: Int, inFile file: StaticString = #file, atLine line: Int = #line) {
        XCTAssert(submitCount.withReadLock({ $0 == times }), "Executor was not called exactly \(times) times", file: file, line: numericCast(line))
    }

    func assertExecutorCalled(atLeast times: Int, inFile file: StaticString = #file, atLine line: Int = #line) {
        XCTAssert(submitCount.withReadLock({ $0 >= times }), "Executor was never called", file: file, line: numericCast(line))
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
        let i = index(startIndex, offsetBy: numericCast(offset))
        return self[i]
    }

}

enum SomeMultipayloadEnum: Hashable {
    case one
    case two(String)
    case three(Double)

    var hashValue: Int {
        switch self {
        case .one:
            return 1
        case .two(let str):
            return str.hashValue
        case .three(let obj):
            return obj.hashValue
        }
    }

    static func == (lhs: SomeMultipayloadEnum, rhs: SomeMultipayloadEnum) -> Bool {
        switch (lhs, rhs) {
        case (.one, .one):
            return true
        case let (.two(lhs), .two(rhs)):
            return lhs == rhs
        case let (.three(lhs), .three(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
