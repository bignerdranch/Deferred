//
//  ExistentialFutureTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred

class ExistentialFutureTests: XCTestCase {
    static var allTests: [(String, (ExistentialFutureTests) -> () throws -> Void)] {
        return [
            ("testFilledAnyFutureWaitAlwaysReturns", testFilledAnyFutureWaitAlwaysReturns),
            ("testAnyWaitWithTimeout", testAnyWaitWithTimeout),
            ("testFilledAnyFutureUpon", testFilledAnyFutureUpon),
            ("testUnfilledAnyUponCalledWhenFilled", testUnfilledAnyUponCalledWhenFilled),
            ("testFillAndIsFilledPostcondition", testFillAndIsFilledPostcondition),
        ]
    }

    var anyFuture: Future<Int>!

    override func tearDown() {
        anyFuture = nil

        super.tearDown()
    }

    func testFilledAnyFutureWaitAlwaysReturns() {
        anyFuture = Future(value: 42)
        let peek = anyFuture.wait(until: .distantFuture)
        XCTAssertNotNil(peek)
    }

    func testAnyWaitWithTimeout() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)

        let expect = expectation(description: "value blocks while unfilled")
        afterDelay(upon: .global()) {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        let peek = anyFuture.waitShort()
        XCTAssertNil(peek)

        waitForExpectations()
    }

    func testFilledAnyFutureUpon() {
        let d = Future(value: 1)

        for _ in 0 ..< 10 {
            let expect = expectation(description: "upon blocks called with correct value")
            d.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testUnfilledAnyUponCalledWhenFilled() {
        let d = Deferred<Int>()
        anyFuture = Future(d)

        for _ in 0 ..< 10 {
            let expect = expectation(description: "upon blocks not called while deferred is unfilled")
            anyFuture.upon { value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(d.value, value)
                expect.fulfill()
            }
        }

        d.fill(with: 1)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testFillAndIsFilledPostcondition() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)
        XCTAssertFalse(anyFuture.isFilled)
        deferred.fill(with: 42)
        XCTAssertNotNil(anyFuture.peek())
        XCTAssertTrue(anyFuture.isFilled)
        XCTAssertNotNil(anyFuture.wait(until: .now()))
        XCTAssertNotNil(anyFuture.waitShort())  // pass
    }
}
