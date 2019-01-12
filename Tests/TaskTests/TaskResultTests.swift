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

// swiftlint:disable type_body_length

class TaskResultTests: XCTestCase {
    static let allTests: [(String, (TaskResultTests) -> () throws -> Void)] = [
        ("testGetSuccess", testGetSuccess),
        ("testGetFailure", testGetFailure),
        ("testCatchingInitTurnsReturnedValueIntoSuccess", testCatchingInitTurnsReturnedValueIntoSuccess),
        ("testCatchingInitTurnsThrownErrorIntoFailure", testCatchingInitTurnsThrownErrorIntoFailure),
        ("testMapSuccess", testMapSuccess),
        ("testMapFailure", testMapFailure),
        ("testMapErrorSuccess", testMapErrorSuccess),
        ("testMapErrorFailure", testMapErrorFailure),
        ("testFlatMapSuccessToSuccess", testFlatMapSuccessToSuccess),
        ("testFlatMapSuccessToFailuure", testFlatMapSuccessToFailuure),
        ("testFlatMapFailureToSuccess", testFlatMapFailureToSuccess),
        ("testFlatMapFailureToFailure", testFlatMapFailureToFailure),
        ("testFlatMapErrorSuccessToSuccess", testFlatMapErrorSuccessToSuccess),
        ("testFlatMapErrorSuccessToFailure", testFlatMapErrorSuccessToFailure),
        ("testFlatMapErrorFailureToSuccess", testFlatMapErrorFailureToSuccess),
        ("testFlatMapErrorFailureToFailure", testFlatMapErrorFailureToFailure),
        ("testCocoaBlockInitSuccess", testCocoaBlockInitSuccess),
        ("testCocoaBlockInitFailure", testCocoaBlockInitFailure),
        ("testCocoaBlockInitInvalid", testCocoaBlockInitInvalid),
        ("testDescriptionSuccess", testDescriptionSuccess),
        ("testDescriptionFailure", testDescriptionFailure),
        ("testDebugDescriptionSuccess", testDebugDescriptionSuccess),
        ("testDebugDescriptionFailure", testDebugDescriptionFailure)
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

    func testCatchingInitTurnsReturnedValueIntoSuccess() {
        let intSuccesss = IntResult { return 99 }
        XCTAssertEqual(try intSuccesss.get(), 99)

        let stringSuccess = StringResult { return "bar" }
        XCTAssertEqual(try stringSuccess.get(), "bar")

        let voidSuccess = VoidResult {}
        XCTAssertNoThrow(try voidSuccess.get())
    }

    func testCatchingInitTurnsThrownErrorIntoFailure() {
        let intFailure = IntResult { throw TestError.first }
        XCTAssertThrowsError(try intFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .first)
        }

        let stringFailure = StringResult { throw TestError.second }
        XCTAssertThrowsError(try stringFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .second)
        }

        let voidFailure = VoidResult { throw TestError.third }
        XCTAssertThrowsError(try voidFailure.get()) { (error) in
            XCTAssertEqual(error as? TestError, .third)
        }
    }

    // MARK: - Functional Transforms

    private func repeated<Value>(_ value: Value) -> String {
        return "\(value)\(value)"
    }

    private func repeatedResult<Value>(_ value: Value) -> StringResult {
        return .success(repeated(value))
    }

    private func ignoreAndReturnError<Value>(_ value: Value) -> Error {
        return TestError.fourth
    }

    private func ignoreAndReturnFailure<Value>(_ value: Value) -> StringResult {
        return .failure(ignoreAndReturnError(value))
    }

    func testMapSuccess() {
        let intSuccess = IntResult.success(42).map(repeated)
        XCTAssertEqual(try intSuccess.get(), "4242")

        let stringSuccess = StringResult.success("foo").map(repeated)
        XCTAssertEqual(try stringSuccess.get(), "foofoo")

        let voidSuccess = VoidResult.success(()).map(repeated)
        XCTAssertEqual(try voidSuccess.get(), "()()")
    }

    func testMapFailure() {
        let intFailure = IntResult.failure(TestError.first).map(repeated)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let stringFailure = StringResult.failure(TestError.second).map(repeated)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let voidFailure = VoidResult.failure(TestError.third).map(repeated)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }
    }

    func testMapErrorSuccess() {
        let intSuccess = IntResult.success(42).mapError(ignoreAndReturnError)
        XCTAssertEqual(try intSuccess.get(), 42)

        let stringSuccess = StringResult.success("foo").mapError(ignoreAndReturnError)
        XCTAssertEqual(try stringSuccess.get(), "foo")

        let voidSuccess = VoidResult.success(()).mapError(ignoreAndReturnError)
        XCTAssertNoThrow(try voidSuccess.get())
    }

    func testMapErrorFailure() {
        let intFailure = IntResult.failure(TestError.first).mapError(ignoreAndReturnError)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }

        let stringFailure = StringResult.failure(TestError.second).mapError(ignoreAndReturnError)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }

        let voidFailure = VoidResult.failure(TestError.third).mapError(ignoreAndReturnError)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }
    }

    func testFlatMapSuccessToSuccess() {
        let intSuccess = IntResult.success(404).flatMap(repeatedResult)
        XCTAssertEqual(try intSuccess.get(), "404404")

        let stringSuccess = StringResult.success("me").flatMap(repeatedResult)
        XCTAssertEqual(try stringSuccess.get(), "meme")

        let voidSuccess = VoidResult.success(()).flatMap(repeatedResult)
        XCTAssertEqual(try voidSuccess.get(), "()()")
    }

    func testFlatMapSuccessToFailuure() {
        let intFailure = IntResult.success(9001).flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }

        let stringFailure = StringResult.success("ooo").flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }

        let voidFailure = VoidResult.success(()).flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }
    }

    func testFlatMapFailureToSuccess() {
        let intFailure = IntResult.failure(TestError.first).flatMap(repeatedResult)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let stringFailure = StringResult.failure(TestError.second).flatMap(repeatedResult)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let voidFailure = VoidResult.failure(TestError.third).flatMap(repeatedResult)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }
    }

    func testFlatMapFailureToFailure() {
        let intFailure = IntResult.failure(TestError.first).flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let stringFailure = StringResult.failure(TestError.second).flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let voidFailure = VoidResult.failure(TestError.third).flatMap(ignoreAndReturnFailure)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }
    }

    func testFlatMapErrorSuccessToSuccess() {
        let stringSuccess = StringResult.success("me").flatMapError(repeatedResult)
        XCTAssertEqual(try stringSuccess.get(), "me")
    }

    func testFlatMapErrorSuccessToFailure() {
        let stringSuccess = StringResult.success("me").flatMapError(ignoreAndReturnFailure)
        XCTAssertEqual(try stringSuccess.get(), "me")
    }

    func testFlatMapErrorFailureToSuccess() {
        let stringFailure = StringResult.failure(TestError.second).flatMapError(repeatedResult)
        XCTAssertEqual(try stringFailure.get(), "secondsecond")
    }

    func testFlatMapErrorFailureToFailure() {
        let stringFailure = StringResult.failure(TestError.second).flatMapError(ignoreAndReturnFailure)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .fourth)
        }
    }

    // MARK: - Initializers

    func testCocoaBlockInitSuccess() {
        let intSuccesss = IntResult(value: 42, error: nil)
        XCTAssertEqual(try intSuccesss.get(), 42)

        let stringSuccess = StringResult(value: "foo", error: nil)
        XCTAssertEqual(try stringSuccess.get(), "foo")

        let voidSuccess = VoidResult(value: (), error: nil)
        XCTAssertNoThrow(try voidSuccess.get())
    }

    func testCocoaBlockInitFailure() {
        let intFailure = IntResult(value: nil, error: TestError.first)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertEqual($0 as? TestError, .first)
        }

        let stringFailure = StringResult(value: nil, error: TestError.second)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertEqual($0 as? TestError, .second)
        }

        let voidFailure = StringResult(value: nil, error: TestError.third)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertEqual($0 as? TestError, .third)
        }
    }

    func testCocoaBlockInitInvalid() {
        let intFailure = IntResult(value: nil, error: nil)
        XCTAssertThrowsError(try intFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }

        let stringFailure = StringResult(value: nil, error: nil)
        XCTAssertThrowsError(try stringFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }

        let voidFailure = VoidResult(value: nil, error: nil)
        XCTAssertThrowsError(try voidFailure.get()) {
            XCTAssertFalse($0 is TestError)
        }
    }

    // MARK: - Descriptions

    func testDescriptionSuccess() {
        let intSuccess = IntResult.success(42)
        XCTAssertEqual(String(describing: intSuccess), "success(42)")

        let stringSuccess = StringResult.success("foo")
        XCTAssertEqual(String(describing: stringSuccess), "success(\"foo\")")

        let voidSuccess = VoidResult.success(())
        XCTAssertEqual(String(describing: voidSuccess), "success()")
    }

    func testDescriptionFailure() {
        let intFailure = IntResult.failure(TestError.first)
        XCTAssertEqual(String(describing: intFailure), "failure(TestError.first)")

        let stringFailure = StringResult.failure(TestError.second)
        XCTAssertEqual(String(describing: stringFailure), "failure(TestError.second)")

        let voidFailure = VoidResult.failure(TestError.third)
        XCTAssertEqual(String(describing: voidFailure), "failure(TestError.third)")
    }

    func testDebugDescriptionSuccess() {
        let intSuccess = IntResult.success(42)
        XCTAssert(String(reflecting: intSuccess).hasSuffix("Task<Swift.Int>.Result.success(42)"))

        let stringSuccess = StringResult.success("foo")
        XCTAssert(String(reflecting: stringSuccess).hasSuffix("Task<Swift.String>.Result.success(\"foo\")"))

        let voidSuccess = VoidResult.success(())
        XCTAssert(String(reflecting: voidSuccess).hasSuffix("Task<()>.Result.success()"))
    }

    func testDebugDescriptionFailure() {
        let intFailure = IntResult.failure(TestError.first)
        XCTAssert(String(reflecting: intFailure).hasSuffix("Task<Swift.Int>.Result.failure(TestError.first)"))

        let stringFailure = StringResult.failure(TestError.second)
        XCTAssert(String(reflecting: stringFailure).hasSuffix("Task<Swift.String>.Result.failure(TestError.second)"))

        let voidFailure = VoidResult.failure(TestError.third)
        XCTAssert(String(reflecting: voidFailure).hasSuffix("Task<()>.Result.failure(TestError.third)"))
    }

}
