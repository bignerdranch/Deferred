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
@testable import Result
#else
@testable import Deferred
#endif

class ResultRecoveryTests: XCTestCase {

    fileprivate typealias Result = TaskResult<String>

    fileprivate func tryIsSuccess(_ text: String?) throws -> String {
        guard let text = text , text == "success" else {
            throw Error.first
        }

        return text
    }

    fileprivate func successFunction() throws -> String {
        return try tryIsSuccess("success")
    }

    fileprivate func failureFunction() throws -> String {
        return try tryIsSuccess(nil)
    }

    func testInitWithFunctionProducesSuccesses() {
        let result = Result(with: successFunction)
        XCTAssertEqual(result.value, "success")
        XCTAssertNil(result.error)
    }

    func testInitWithFunctionProducesFailures() {
        let result = Result(with: failureFunction)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.error as? Error, Error.first)
    }

}
