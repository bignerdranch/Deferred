//
//  TaskResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 2/7/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

import Deferred
#if SWIFT_PACKAGE
import Task
#endif

class TaskResultTests: XCTestCase {
    static let allTests: [(String, (TaskResultTests) -> () throws -> Void)] = [
        ("testCocoaBlockInitSuccess", testCocoaBlockInitSuccess),
        ("testCocoaBlockInitFailure", testCocoaBlockInitFailure),
        ("testCocoaBlockInitInvalid", testCocoaBlockInitInvalid)
    ]

    // MARK: - Initializers

    func testCocoaBlockInitSuccess() {
        let intSuccesss = Result<Int, Error>(value: 42, error: nil)
        XCTAssertEqual(try intSuccesss.get(), 42)

        let stringSuccess = Result<String, Error>(value: "foo", error: nil)
        XCTAssertEqual(try stringSuccess.get(), "foo")

        let voidSuccess = Result<Void, Error>(value: (), error: nil)
        XCTAssertNoThrow(try voidSuccess.get())
    }

    func testCocoaBlockInitFailure() {
        let intFailure = Result<Int, Error>(value: nil, error: TestError.first)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let stringFailure = Result<String, Error>(value: nil, error: TestError.second)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let voidFailure = Result<String, Error>(value: nil, error: TestError.third)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }
    }

    func testCocoaBlockInitInvalid() {
        let intFailure = Result<Int, Error>(value: nil, error: nil)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }

        let stringFailure = Result<String, Error>(value: nil, error: nil)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }

        let voidFailure = Result<Void, Error>(value: nil, error: nil)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }
    }

}
