//
//  TaskTestsCommon.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 5/3/17.
//  Copyright © 2014-2017 Big Nerd Ranch. All rights reserved.
//

import XCTest

#if SWIFT_PACKAGE
@testable import Task
#else
@testable import Deferred
#endif

extension XCTestCase {
    func waitForTaskToComplete<T>(_ task: Task<T>, file: StaticString = #file, line: Int = #line) -> Task<T>.Result {
        let expectation = self.expectation(description: "task completed")
        var result: Task<T>.Result?
        task.upon(.main) { [weak expectation] in
            result = $0
            expectation?.fulfill()
        }
        waitForExpectations(file: file, line: numericCast(line))

        return result!
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
