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

    private let aSuccessResult = Result.success(())
    private let aFailureResult = Result.failure(Error.first)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(describing: aSuccessResult), "()")
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(describing: aFailureResult), "first")
    }

    func testDebugDescriptionSuccess() {
        XCTAssert(String(reflecting: aSuccessResult) == "success(())")
    }

    func testDebugDescriptionFailure() {
        let debugDescription = String(reflecting: aFailureResult)
        XCTAssert(debugDescription.hasPrefix("failure("))
        XCTAssert(debugDescription.hasSuffix("Error.first)"))
    }

    func testExtract() {
        XCTAssertNotNil(try? aSuccessResult.extract())
        XCTAssertNil(try? aFailureResult.extract())
    }

}
