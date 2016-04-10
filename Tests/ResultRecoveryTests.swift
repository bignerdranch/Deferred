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

    private typealias Result = TaskResult<String>

    private func tryIsSuccess(text: String?) throws -> String {
        guard let text = text where text == "success" else {
            throw Error.First
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
        let result = Result(with: successFunction)
        XCTAssertEqual(result.value, "success")
        XCTAssertNil(result.error)
    }

    func testInitWithFunctionProducesFailures() {
        let result = Result(with: failureFunction)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.error as? Error, Error.First)
    }

}
