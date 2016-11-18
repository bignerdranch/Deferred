//
//  FutureTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/24/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest
import Dispatch

@testable import Deferred
#if SWIFT_PACKAGE
import Atomics
@testable import TestSupport
#else
import Deferred.Atomics
#endif

class FutureTests: XCTestCase {
    static var allTests: [(String, (FutureTests) -> () throws -> Void)] {
        return [
            ("testAnd", testAnd),
            ("testAllFilled", testAllFilled),
            ("testAllFilledEmptyCollection", testAllFilledEmptyCollection),
            ("testFirstFilled", testFirstFilled),
        ]
    }

    func testAnd() {
        let d1 = Deferred<Int>()
        let d2 = Deferred<String>()
        let both = d1.and(d2)

        let expectation = self.expectation(description: "paired deferred should be filled")
        both.upon(.main) { (value) in
            XCTAssertEqual(value.0, 1)
            XCTAssertEqual(value.1, "foo")
            expectation.fulfill()
        }

        XCTAssertFalse(both.isFilled)
        d1.fill(with: 1)

        XCTAssertFalse(both.isFilled)
        d2.fill(with: "foo")

        waitForExpectations()
    }

    func testAllFilled() {
        var d = [Deferred<Int>]()

        for _ in 0 ..< 10 {
            d.append(Deferred())
        }

        let w = d.allFilled()
        let outerExpectation = expectation(description: "all results filled in")
        let innerExpectation = expectation(description: "paired deferred should be filled")

        // skip first
        for i in 1 ..< d.count {
            d[i].fill(with: i)
        }

        afterDelay {
            XCTAssertFalse(w.isFilled) // unfilled because d[0] is still unfilled
            d[0].fill(with: 0)

            self.afterDelay {
                XCTAssertTrue(w.value == [Int](0 ..< d.count))
                innerExpectation.fulfill()
            }
            outerExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testAllFilledEmptyCollection() {
        let d = EmptyCollection<Deferred<Int>>().allFilled()
        XCTAssert(d.isFilled)
    }

    func testFirstFilled() {
        let d = (0 ..< 10).map { _ in Deferred<Int>() }
        let w = d.firstFilled()

        d[3].fill(with: 3)

        let outerExpectation = expectation(description: "any is filled")
        let innerExpectation = expectation(description: "any is not changed")

        afterDelay {
            XCTAssertEqual(w.value, 3)

            d[4].fill(with: 4)

            self.afterDelay {
                XCTAssertEqual(w.value, 3)
                innerExpectation.fulfill()
            }

            outerExpectation.fulfill()
        }

        waitForExpectations()
    }

    func testEveryMapTransformerIsCalledMultipleTimes() {
        let d = Deferred(filledWith: 1)
        var counter = UnsafeAtomicCounter()

        let mapped = d.every { (value) -> (Int) in
            counter.increment()
            return value * 2
        }

        let expect = expectation(description: "upon is called when filled")
        mapped.upon { (value) in
            XCTAssertEqual(value, 2)
            expect.fulfill()
        }
        waitForExpectationsShort()

        XCTAssertEqual(mapped.waitShort(), 2)

        XCTAssertEqual(counter.load(), 2)
    }
}
