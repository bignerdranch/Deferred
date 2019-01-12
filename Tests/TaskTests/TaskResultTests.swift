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
        ("testGetSuccess", testGetSuccess),
        ("testGetFailure", testGetFailure),
        ("testDescriptionSuccess", testDescriptionSuccess),
        ("testDescriptionFailure", testDescriptionFailure),
        ("testDebugDescriptionSuccess", testDebugDescriptionSuccess),
        ("testDebugDescriptionFailure", testDebugDescriptionFailure),
        ("testInitializeWithBlockSuccess", testInitializeWithBlockSuccess),
        ("testInitializeWithBlockError", testInitializeWithBlockError),
        ("testInitializeWithBlockInitFailure", testInitializeWithBlockInitFailure)
    ]

    private typealias IntResult = Task<Int>.Result
    private typealias StringResult = Task<String>.Result
    private typealias VoidResult = Task<Void>.Result

    // MARK: - Throwing Initialization and Unwrapping

    func testGetSuccess() {
        let intSuccess = IntResult(success: 42)
        XCTAssertEqual(try intSuccess.get(), 42)

        let stringSuccess = StringResult(success: "foo")
        XCTAssertEqual(try stringSuccess.get(), "foo")

        let voidSuccess = VoidResult()
        XCTAssertNoThrow(try voidSuccess.get())
    }

    func testGetFailure() {
        let intFailure = IntResult(failure: TestError.first)
        XCTAssertThrowsError(try intFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .first)
        }

        let stringFailure = StringResult(failure: TestError.second)
        XCTAssertThrowsError(try stringFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .second)
        }

        let voidFailure = VoidResult(failure: TestError.third)
        XCTAssertThrowsError(try voidFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .third)
        }
    }

    // MARK: -

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

    func testInitializeWithBlockSuccess() {
        let result = Result(value: 42, error: nil)
        XCTAssertEqual(try result.get(), 42)
    }

    func testInitializeWithBlockError() {
        let result = Result(value: nil, error: TestError.first)
        XCTAssertThrowsError(try result.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }
    }

    func testInitializeWithBlockInitFailure() {
        let result = Result(value: nil, error: nil)
        XCTAssertThrowsError(try result.get())
    }
}
