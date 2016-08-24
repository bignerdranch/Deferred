//
//  VoidResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 3/27/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Deferred
@testable import Result
#else
@testable import Deferred
#endif

class VoidResultTests: XCTestCase {

    private typealias Result = TaskResult<Void>

    private let aSuccessResult = Result.Success(())
    private let aFailureResult = Result.Failure(Error.First)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(aSuccessResult), "()")
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(aFailureResult), "First")
    }

    func testDebugDescriptionSuccess() {
        XCTAssert(String(reflecting: aSuccessResult) == "Success(())")
    }

    func testDebugDescriptionFailure() {
        let debugDescription = String(reflecting: aFailureResult)
        XCTAssert(debugDescription.hasPrefix("Failure("))
        XCTAssert(debugDescription.hasSuffix("Error.First)"))
    }

    func testExtract() {
        XCTAssertNotNil(try? aSuccessResult.extract())
        XCTAssertNil(try? aFailureResult.extract())
    }

}
