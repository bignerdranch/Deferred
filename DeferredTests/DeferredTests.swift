//
//  DeferredTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Deferred

func after(interval: NSTimeInterval, upon queue: dispatch_queue_t = dispatch_get_main_queue(), function: () -> ()) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC) * interval)),
        queue, function)
}

class DeferredTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()

        let expect = expectationWithDescription("value blocks while unfilled")
        after(1, upon: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            deferred.fill(42)
            expect.fulfill()
        }

        let peek = deferred.wait(.Interval(0.5))
        XCTAssertNil(peek)

        waitForExpectationsWithTimeout(1.5, handler: nil)
    }

    func testPeek() {
        let d1 = Deferred<Int>()
        let d2 = Deferred(value: 1)
        XCTAssertNil(d1.peek())
        XCTAssertEqual(d2.value, 1)
    }

    func testValueOnFilled() {
        let filled = Deferred(value: 2)
        XCTAssertEqual(filled.value, 2)
    }

    func testValueBlocksWhileUnfilled() {
        let unfilled = Deferred<Int>()

        let expect = expectationWithDescription("value blocks while unfilled")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            _ = unfilled.value
            XCTFail("value did not block")
        }
        after(0.1) {
            expect.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testValueUnblocksWhenUnfilledIsFilled() {
        let d = Deferred<Int>()
        let expect = expectationWithDescription("value blocks until filled")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            XCTAssertEqual(d.value, 3)
            expect.fulfill()
        }
        after(0.1) {
            d.fill(3)
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testFill() {
        let d = Deferred<Int>()
        d.fill(1)
        XCTAssertEqual(d.value, 1)
    }

    func testFillMultipleTimes() {
        let d = Deferred(value: 1)
        XCTAssertEqual(d.value, 1)
        d.fill(2, assertIfFilled: false)
        XCTAssertEqual(d.value, 1)
    }

    func testIsFilled() {
        let d = Deferred<Int>()
        XCTAssertFalse(d.isFilled)

        let expect = expectationWithDescription("isFilled is true when filled")
        d.upon { _ in
            XCTAssertTrue(d.isFilled)
            expect.fulfill()
        }
        d.fill(1)
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testUponWithFilled() {
        let d = Deferred(value: 1)

        for _ in 0 ..< 10 {
            let expect = expectationWithDescription("upon blocks called with correct value")
            d.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testUponNotCalledWhileUnfilled() {
        let d = Deferred<Int>()

        d.upon { _ in
            XCTFail("unexpected upon block call")
        }

        let expect = expectationWithDescription("upon blocks not called while deferred is unfilled")
        after(0.1) {
            expect.fulfill()
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testUponCalledWhenFilled() {
        let d = Deferred<Int>()

        for _ in 0 ..< 10 {
            let expect = expectationWithDescription("upon blocks not called while deferred is unfilled")
            d.upon { value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(d.value, value)
                expect.fulfill()
            }
        }

        d.fill(1)

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testConcurrentUpon() {
        let d = Deferred<Int>()
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

        // upon with an unfilled deferred appends to an internal array (protected by a write lock)
        // spin up a bunch of these in parallel...
        for i in 0 ..< 32 {
            let expectUponCalled = expectationWithDescription("upon block \(i)")
            dispatch_async(queue) {
                d.upon { _ in expectUponCalled.fulfill() }
            }
        }

        // ...then fill it (also in parallel)
        dispatch_async(queue) { d.fill(1) }

        // ... and make sure all our upon blocks were called (i.e., the write lock protected access)
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testBoth() {
        let d1 = Deferred<Int>()
        let d2 = Deferred<String>()
        let both = d1.both(d2)

        XCTAssertFalse(both.isFilled)

        d1.fill(1)
        XCTAssertFalse(both.isFilled)
        d2.fill("foo")

        let expectation = expectationWithDescription("paired deferred should be filled")
        both.upon { _ in
            XCTAssert(d1.isFilled)
            XCTAssert(d2.isFilled)
            XCTAssertEqual(both.value.0, 1)
            XCTAssertEqual(both.value.1, "foo")
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testAll() {
        var d = [Deferred<Int>]()

        for _ in 0 ..< 10 {
            d.append(Deferred())
        }

        let w = all(d)
        let outerExpectation = expectationWithDescription("all results filled in")
        let innerExpectation = expectationWithDescription("paired deferred should be filled")

        // skip first
        for i in 1 ..< d.count {
            d[i].fill(i)
        }

        after(0.1) {
            XCTAssertFalse(w.isFilled) // unfilled because d[0] is still unfilled
            d[0].fill(0)

            after(0.1) {
                XCTAssertTrue(w.value == [Int](0 ..< d.count))
                innerExpectation.fulfill()
            }
            outerExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testAllEmptyArray() {
        let d = [Deferred<Int>]()
        let array = all(d)
        XCTAssert(array.isFilled)
    }

    func testAny() {
        let d = map(0 ..< 10) { _ in Deferred<Int>() }
        let w = any(d)

        d[3].fill(3)

        let outerExpectation = expectationWithDescription("any is filled")
        let innerExpectation = expectationWithDescription("any is not changed")

        after(0.1) {
            XCTAssertEqual(w.value.value, 3)

            d[4].fill(4)

            after(0.1) {
                XCTAssertEqual(w.value.value, 3)
                innerExpectation.fulfill()
            }

            outerExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(1, handler: nil)
    }

    /// Deferred values behave as values: All copies reflect the same value.
    /// The wrinkle of course is that the value might not be observable till a later
    /// date.
    func testAllCopiesOfADeferredValueRepresentTheSameDeferredValue() {
        let parent = Deferred<Int>()
        let child1 = parent
        let child2 = parent
        let allDeferreds = [parent, child1, child2]

        let anyValue = 42
        let expectedValues = [Int](count: count(allDeferreds), repeatedValue: anyValue)

        let allShouldBeFulfilled = expectationWithDescription("filling any copy fulfills all")
        all(allDeferreds).upon {
            [weak allShouldBeFulfilled] allValues in
            allShouldBeFulfilled?.fulfill()

            XCTAssertEqual(allValues, expectedValues, "all deferreds are the same value")
        }

        let randomIndex = arc4random_uniform(numericCast(allDeferreds.count))
        let oneOfTheDeferreds = allDeferreds[numericCast(randomIndex)]
        oneOfTheDeferreds.fill(anyValue)

        waitForExpectationsWithTimeout(0.5, handler: nil)
    }
    
    func testDeferredOptionalBehavesCorrectly() {
        let d = Deferred<Optional<Int>>(value: .None)

        let beforeExpectation = expectationWithDescription("already filled with nil optional")
        d.upon {
            XCTAssert($0 == .None)
            beforeExpectation.fulfill()
        }

        d.fill(42, assertIfFilled: false)

        let afterExpectation = expectationWithDescription("stays filled with same optional")
        d.upon {
            XCTAssert($0 == .None)
            afterExpectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(0.5, handler: nil)
    }
    
}
