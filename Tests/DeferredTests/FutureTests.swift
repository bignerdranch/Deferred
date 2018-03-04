//
//  FutureTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/24/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch

@testable import Deferred
#if SWIFT_PACKAGE
import Atomics
#else
import Deferred.Atomics
#endif

class FutureTests: XCTestCase {
    static let allTests: [(String, (FutureTests) -> () throws -> Void)] = [
        ("testAnd", testAnd),
        ("testAllFilled", testAllFilled),
        ("testAllFilledEmptyCollection", testAllFilledEmptyCollection),
        ("testFirstFilled", testFirstFilled)
    ]

    func testAnd() {
        let d1 = Deferred<Int>()
        let d2 = Deferred<String>()
        let both = d1.and(d2)

        let expect = expectation(description: "paired deferred should be filled")
        both.upon(.main) { (value) in
            XCTAssertEqual(value.0, 1)
            XCTAssertEqual(value.1, "foo")
            expect.fulfill()
        }

        XCTAssertFalse(both.isFilled)
        d1.fill(with: 1)

        XCTAssertFalse(both.isFilled)
        d2.fill(with: "foo")

        shortWait(for: [ expect ])
    }

    func testAllFilled() {
        var d = [Deferred<Int>]()

        for _ in 0 ..< 10 {
            d.append(Deferred())
        }

        let w = d.allFilled()
        let outerExpect = expectation(description: "all results filled in")
        let innerExpect = expectation(description: "paired deferred should be filled")

        // skip first
        for i in 1 ..< d.count {
            d[i].fill(with: i)
        }

        self.afterShortDelay {
            XCTAssertFalse(w.isFilled) // unfilled because d[0] is still unfilled
            d[0].fill(with: 0)

            self.afterShortDelay {
                XCTAssertTrue(w.value == [Int](0 ..< d.count))
                innerExpect.fulfill()
            }
            outerExpect.fulfill()
        }

        shortWait(for: [ outerExpect, innerExpect ])
    }

    func testAllFilledEmptyCollection() {
        let deferred = EmptyCollection<Deferred<Int>>().allFilled()
        XCTAssert(deferred.isFilled)
    }

    func testFirstFilled() {
        let allDeferreds = (0 ..< 10).map { _ in Deferred<Int>() }
        let winner = allDeferreds.firstFilled()

        allDeferreds[3].fill(with: 3)

        let outerExpect = expectation(description: "any is filled")
        let innerExpect = expectation(description: "any is not changed")

        self.afterShortDelay {
            XCTAssertEqual(winner.value, 3)

            allDeferreds[4].fill(with: 4)

            self.afterShortDelay {
                XCTAssertEqual(winner.value, 3)
                innerExpect.fulfill()
            }

            outerExpect.fulfill()
        }

        shortWait(for: [ outerExpect, innerExpect ])
    }

    func testEveryMapTransformerIsCalledMultipleTimes() {
        let deferred = Deferred(filledWith: 1)
        var counter = UnsafeAtomicCounter()

        let mapped = deferred.every { (value) -> (Int) in
            bnr_atomic_counter_increment(&counter)
            return value * 2
        }

        let expect = expectation(description: "upon is called when filled")
        mapped.upon { (value) in
            XCTAssertEqual(value, 2)
            expect.fulfill()
        }
        shortWait(for: [ expect ])

        XCTAssertEqual(mapped.value, 2)
        XCTAssertEqual(bnr_atomic_counter_load(&counter), 2)
    }
}
