//
//  TaskResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 2/7/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskResultTests: XCTestCase {
    static let allTests: [(String, (TaskResultTests) -> () throws -> Void)] = [
        ("testDescriptionSuccess", testDescriptionSuccess),
        ("testDescriptionFailure", testDescriptionFailure),
        ("testDebugDescriptionSuccess", testDebugDescriptionSuccess),
        ("testDebugDescriptionFailure", testDebugDescriptionFailure),
        ("testSuccessExtract", testSuccessExtract),
        ("testFailureExtract", testFailureExtract),
        ("testInitializeWithBlockSuccess", testInitializeWithBlockSuccess),
        ("testInitializeWithBlockError", testInitializeWithBlockError),
        ("testInitializeWithBlockInitFailure", testInitializeWithBlockInitFailure)
    ]

    private typealias Result = Task<Int>.Result

    private let aSuccessResult = Result(success: 42)
    private let aFailureResult = Result(failure: TestError.first)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(describing: aSuccessResult), "success(42)")
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(describing: aFailureResult), "failure(TestError.first)")
    }

    func testDebugDescriptionSuccess() {
        let debugDescription = String(reflecting: aSuccessResult)
        XCTAssert(debugDescription.hasSuffix("Task<Swift.Int>.Result.success(42)"))
    }

    func testDebugDescriptionFailure() {
        let debugDescription = String(reflecting: aFailureResult)
        XCTAssert(debugDescription.hasSuffix("Task<Swift.Int>.Result.failure(TestError.first)"))
    }

    func testSuccessExtract() {
        XCTAssertEqual(try aSuccessResult.extract(), 42)
    }

    func testFailureExtract() {
        XCTAssertThrowsError(try aFailureResult.extract())
    }

    func testInitializeWithBlockSuccess() {
        let result = Result(value: 42, error: nil)
        XCTAssertEqual(try result.extract(), 42)
    }

    func testInitializeWithBlockError() {
        let result = Result(value: nil, error: TestError.first)
        XCTAssertThrowsError(try result.extract()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }

    func testInitializeWithBlockInitFailure() {
        let result = Result(value: nil, error: nil)
        XCTAssertThrowsError(try result.extract())
    }
}
