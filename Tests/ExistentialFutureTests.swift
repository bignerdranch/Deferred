//
//  ExistentialFutureTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred

class ExistentialFutureTests: XCTestCase {

    var anyFuture: Future<Int>!

    override func tearDown() {
        anyFuture = nil

        super.tearDown()
    }

    func testFilledAnyFutureWaitAlwaysReturns() {
        anyFuture = Future(value: 42)
        let peek = anyFuture.wait(.Forever)
        XCTAssertNotNil(peek)
    }

    func testAnyWaitWithTimeout() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)

        let expect = expectationWithDescription("value blocks while unfilled")
        afterDelay(1, upon: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            deferred.fill(42)
            expect.fulfill()
        }

        let peek = anyFuture.wait(.Interval(0.5))
        XCTAssertNil(peek)

        waitForExpectationsWithTimeout(1.5, handler: nil)
    }

    func testFilledAnyFutureUpon() {
        let d = Future(value: 1)

        for _ in 0 ..< 10 {
            let expect = expectationWithDescription("upon blocks called with correct value")
            d.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testUnfilledAnyUponCalledWhenFilled() {
        let d = Deferred<Int>()
        anyFuture = Future(d)

        for _ in 0 ..< 10 {
            let expect = expectationWithDescription("upon blocks not called while deferred is unfilled")
            anyFuture.upon { value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(d.value, value)
                expect.fulfill()
            }
        }

        d.fill(1)

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testFillAndIsFilledPostcondition() {
        let deferred = Deferred<Int>()
        anyFuture = Future(deferred)
        XCTAssertFalse(anyFuture.isFilled)
        deferred.fill(42)
        XCTAssertNotNil(anyFuture.peek())
        XCTAssertTrue(anyFuture.isFilled)
        XCTAssertNotNil(anyFuture.wait(.Now))
        XCTAssertNotNil(anyFuture.wait(.Interval(0.1)))  // pass
    }

}
