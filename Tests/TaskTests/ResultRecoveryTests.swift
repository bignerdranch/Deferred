//
//  ResultRecoveryTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 12/16/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
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
        ("testMap", testMap),
        ("testFlatMap", testFlatMap),
        ("testInitWithFunctionProducesSuccesses", testInitWithFunctionProducesSuccesses),
        ("testInitWithFunctionProducesFailures", testInitWithFunctionProducesFailures)
    ]

    private typealias Result = Task<String>.Result

    private let aSuccessResult = Result(success: "foo")
    private let aFailureResult = Result(failure: TestError.first)

    func testMap() {
        let successResult1: Result = aSuccessResult.map { "\($0)\($0)" }
        XCTAssertEqual(try successResult1.get(), "foofoo")

        let successResult2: Result = aSuccessResult.map { _ in throw TestError.second }
        XCTAssertThrowsError(try successResult2.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let failureResult1: Result = aFailureResult.map { "\($0)\($0)" }
        XCTAssertThrowsError(try failureResult1.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let failureResult2: Result = aFailureResult.map { _ in throw TestError.second }
        XCTAssertThrowsError(try failureResult2.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }

    func testFlatMap() {
        let successResult1: Result = aSuccessResult.flatMap { .success("\($0)\($0)") }
        XCTAssertEqual(try successResult1.get(), "foofoo")

        let successResult2: Result = aSuccessResult.flatMap { _ in throw TestError.second }
        XCTAssertThrowsError(try successResult2.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let successResult3: Result = aSuccessResult.flatMap { _ in .failure(TestError.third) }
        XCTAssertThrowsError(try successResult3.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }

        let failureResult1: Result = aFailureResult.flatMap { .success("\($0)\($0)") }
        XCTAssertThrowsError(try failureResult1.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let failureResult2: Result = aFailureResult.flatMap { _ in throw TestError.second }
        XCTAssertThrowsError(try failureResult2.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let failureResult3: Result = aFailureResult.flatMap { _ in .failure(TestError.third) }
        XCTAssertThrowsError(try failureResult3.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }

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
        XCTAssertEqual(try result.get(), "success")
    }

    func testInitWithFunctionProducesFailures() {
        let result = Result(from: failureFunction)
        XCTAssertThrowsError(try result.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }
}
