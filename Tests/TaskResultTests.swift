//
//  ResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 2/7/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Deferred
@testable import Result
#else
@testable import Deferred
#endif

class ResultTests: XCTestCase {

    typealias Result = TaskResult<Int>

    private let aSuccessResult = Result.Success(42)
    private let aFailureResult = Result.Failure(Error.First)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(aSuccessResult), String(42))
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(aFailureResult), "First")
    }

    func testDebugDescriptionSuccess() {
        XCTAssertEqual(String(reflecting: aSuccessResult), "Success(\(String(reflecting: 42)))")
    }

    func testDebugDescriptionFailure() {
        let debugDescription1 = String(reflecting: aFailureResult)
        XCTAssert(debugDescription1.hasPrefix("Failure("))
        XCTAssert(debugDescription1.hasSuffix("Error.First)"))
    }

    func testSuccessExtract() {
        XCTAssertEqual(try? aSuccessResult.extract(), 42)
    }

    func testFailureExtract() {
        XCTAssertNil(try? aFailureResult.extract())
    }

    func testCoalesceSuccessValue() {
        XCTAssertEqual(aSuccessResult ?? 43, 42)
    }

    func testCoalesceFailureValue() {
        XCTAssertEqual(aFailureResult ?? 43, 43)
    }

    func testFlatCoalesceSuccess() {
        let x = aSuccessResult ?? Result.Success(84)
        XCTAssertEqual(x.value, 42)
        XCTAssertNil(x.error)
    }

    func testFlatCoalesceFailure() {
        let x = aFailureResult ?? Result(value: 84)
        XCTAssertEqual(x.value, 84)
        XCTAssertNil(x.error)
    }

}
