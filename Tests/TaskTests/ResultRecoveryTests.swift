//
//  ResultRecoveryTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 12/16/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class ResultRecoveryTests: XCTestCase {
    static let allTests: [(String, (ResultRecoveryTests) -> () throws -> Void)] = [
        ("testInitWithFunctionProducesSuccesses", testInitWithFunctionProducesSuccesses),
        ("testInitWithFunctionProducesFailures", testInitWithFunctionProducesFailures)
    ]

    private typealias Result = Task<String>.Result

    private func tryIsSuccess(_ text: String?) throws -> String {
        guard let text = text, text == "success" else {
            throw TestError.first
        }

        return text
    }

    private func successFunction() throws -> String {
        return try tryIsSuccess("success")
    }

    private func failureFunction() throws -> String {
        return try tryIsSuccess(nil)
    }

    func testInitWithFunctionProducesSuccesses() {
        let result = Result(from: successFunction)
        XCTAssertEqual(try result.extract(), "success")
    }

    func testInitWithFunctionProducesFailures() {
        let result = Result(from: failureFunction)
        XCTAssertThrowsError(try result.extract()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }
}
