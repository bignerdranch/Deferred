//
//  ResultRecoveryTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 12/16/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class ResultRecoveryTests: XCTestCase {
    static var allTests: [(String, (ResultRecoveryTests) -> () throws -> Void)] {
        return [
            ("testInitWithFunctionProducesSuccesses", testInitWithFunctionProducesSuccesses),
            ("testInitWithFunctionProducesFailures", testInitWithFunctionProducesFailures),
        ]
    }

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
        XCTAssertEqual(result.value, "success")
        XCTAssertNil(result.error)
    }

    func testInitWithFunctionProducesFailures() {
        let result = Result(from: failureFunction)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.error as? TestError, .first)
    }
}
