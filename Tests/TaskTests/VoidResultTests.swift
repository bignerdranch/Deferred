//
//  VoidResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 3/27/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class VoidResultTests: XCTestCase {
    static let allTests: [(String, (VoidResultTests) -> () throws -> Void)] = [
        ("testDescriptionSuccess", testDescriptionSuccess),
        ("testDescriptionFailure", testDescriptionFailure),
        ("testDebugDescriptionSuccess", testDebugDescriptionSuccess),
        ("testDebugDescriptionFailure", testDebugDescriptionFailure),
        ("testExtract", testExtract)
    ]

    private typealias Result = Task<Void>.Result

    private let aSuccessResult = Result()
    private let aFailureResult = Result(failure: TestError.first)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(describing: aSuccessResult), "success()")
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(describing: aFailureResult), "failure(TestError.first)")
    }

    func testDebugDescriptionSuccess() {
        let debugDescription = String(reflecting: aSuccessResult)
        XCTAssert(debugDescription.hasSuffix("Task<()>.Result.success()"))
    }

    func testDebugDescriptionFailure() {
        let debugDescription = String(reflecting: aFailureResult)
        XCTAssert(debugDescription.hasSuffix("Task<()>.Result.failure(TestError.first)"))
    }

    func testExtract() {
        XCTAssertNoThrow(try aSuccessResult.extract())
        XCTAssertThrowsError(try aFailureResult.extract())
    }
}
