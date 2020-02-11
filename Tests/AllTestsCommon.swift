//
//  AllTestsCommon.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 6/10/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Deferred

enum TestError: Error, CustomStringConvertible, CustomDebugStringConvertible {
    case first
    case second
    case third
    case fourth

    var description: String {
        switch self {
        case .first:
            return "first"
        case .second:
            return "second"
        case .third:
            return "third"
        case .fourth:
            return "fourth"
        }
    }

    var debugDescription: String {
        switch self {
        case .first:
            return "TestError.first"
        case .second:
            return "TestError.second"
        case .third:
            return "TestError.third"
        case .fourth:
            return "TestError.fourth"
        }
    }
}

// MARK: -

extension XCTestCase {
    func expectation(deallocationOf object: AnyObject) -> XCTestExpectation {
        return expectation(for: NSPredicate(block: { [weak object] (_, _) -> Bool in
            object == nil
        }), evaluatedWith: NSNull(), handler: nil)
    }

    var shortTimeoutInverted: TimeInterval {
        return 0.5
    }

    var shortTimeout: TimeInterval {
        return 3
    }

    var longTimeout: TimeInterval {
        return 10
    }

    func afterShortDelay(upon queue: DispatchQueue = .global(), execute body: @escaping() -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3, execute: body)
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

    func shortWait() -> Value? {
        return wait(until: .now() + 0.05)
    }
}

// MARK: -

private class CountingExecutor: Executor {
    let submitCount = Protected(initialValue: 0)

    init() {}

    func submit(_ body: @escaping() -> Void) {
        submitCount.withWriteLock { $0 += 1 }
        body()
    }
}

class CustomExecutorTestCase: XCTestCase {
    private let _customExecutor = CountingExecutor()

    final var customExecutor: Executor {
        return _customExecutor
    }

    final func expectationThatCustomExecutor(isCalledAtLeast times: Int) -> XCTestExpectation {
        return expectation(for: NSPredicate(block: { (sself, _) -> Bool in
            guard let sself = sself as? CustomExecutorTestCase else { return false }
            return sself._customExecutor.submitCount.withReadLock({ $0 >= times })
        }), evaluatedWith: self)
    }

    final let customQueue = DispatchQueue(label: "com.bignerdranch.DeferredTests")

    final func expectCustomQueueToBeEmpty() -> XCTestExpectation {
        let expect = expectation(description: "queue is empty")
        customQueue.async(flags: .barrier) {
            expect.fulfill()
        }
        return expect
    }
}
