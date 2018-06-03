//
//  ExistentialFutureTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

import Deferred

class ExistentialFutureTests: XCTestCase {
    static let allTests: [(String, (ExistentialFutureTests) -> () throws -> Void)] = [
        ("testPeekWhenFilled", testPeekWhenFilled),
        ("testPeekWhenUnfilled", testPeekWhenUnfilled),
        ("testAnyWaitWithTimeout", testAnyWaitWithTimeout),
        ("testFilledAnyFutureUpon", testFilledAnyFutureUpon),
        ("testUnfilledAnyUponCalledWhenFilled", testUnfilledAnyUponCalledWhenFilled),
        ("testFillAndIsFilledPostcondition", testFillAndIsFilledPostcondition),
        ("testDebugDescriptionUnfilled", testDebugDescriptionUnfilled),
        ("testDebugDescriptionFilled", testDebugDescriptionFilled),
        ("testDebugDescriptionFilledWhenValueIsVoid", testDebugDescriptionFilledWhenValueIsVoid),
        ("testReflectionUnfilled", testReflectionUnfilled),
        ("testReflectionFilled", testReflectionFilled),
        ("testReflectionFilledWhenValueIsVoid", testReflectionFilledWhenValueIsVoid)
    ]

    var anyFuture: Future<Int>!

    override func tearDown() {
        anyFuture = nil

        super.tearDown()
    }

    func testPeekWhenFilled() {
        anyFuture = Future(value: 42)
        let peek = anyFuture.peek()
        XCTAssertNotNil(peek)
    }

    func testPeekWhenUnfilled() {
        anyFuture = Future<Int>.never
        let peek = anyFuture.peek()
        XCTAssertNil(peek)
    }

    func testAnyWaitWithTimeout() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)

        let expect = expectation(description: "value blocks while unfilled")
        afterShortDelay {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        XCTAssertNil(anyFuture.shortWait())

        shortWait(for: [ expect ])
    }

    func testFilledAnyFutureUpon() {
        let future = Future(value: 1)
        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) called with correct value")
            future.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
            return expect
        }
        shortWait(for: allExpectations)
    }

    func testUnfilledAnyUponCalledWhenFilled() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)

        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) not called while deferred is unfilled")
            anyFuture.upon { value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(deferred.value, value)
                expect.fulfill()
            }
            return expect
        }

        deferred.fill(with: 1)
        shortWait(for: allExpectations)
    }

    func testFillAndIsFilledPostcondition() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)
        XCTAssertNil(anyFuture.peek())
        XCTAssertFalse(anyFuture.isFilled)
        deferred.fill(with: 42)
        XCTAssertNotNil(anyFuture.peek())
        XCTAssertTrue(anyFuture.isFilled)
    }

    func testDebugDescriptionUnfilled() {
        let future = Future<Int>.never
        XCTAssertEqual("\(future)", "Future(not filled)")
    }

    func testDebugDescriptionFilled() {
        let future = Future<Int>(value: 42)
        XCTAssertEqual("\(future)", "Future(42)")
    }

    func testDebugDescriptionFilledWhenValueIsVoid() {
        let future = Future<Void>(value: ())
        XCTAssertEqual("\(future)", "Future(filled)")
    }

    func testReflectionUnfilled() {
        let future = Future<Int>.never

        let magicMirror = Mirror(reflecting: future)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, false)
    }

    func testReflectionFilled() {
        let future = Future<Int>(value: 42)

        let magicMirror = Mirror(reflecting: future)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? Int, 42)
    }

    func testReflectionFilledWhenValueIsVoid() {
        let future = Future<Void>(value: ())

        let magicMirror = Mirror(reflecting: future)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, true)
    }
}
