//
//  DeferredTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred
#if SWIFT_PACKAGE
@testable import TestSupport
#endif

import Dispatch
#if os(Linux)
    import Glibc
#endif

class DeferredTests: XCTestCase {

    static var allTests: [(String, (DeferredTests) -> () throws -> Void)] {
        let universalTests: [(String, (DeferredTests) -> () throws -> Void)] = [
            ("testDestroyedWithoutBeingFilled", testDestroyedWithoutBeingFilled),
            ("testWaitWithTimeout", testWaitWithTimeout),
            ("testPeek", testPeek),
            ("testValueOnFilled", testValueOnFilled),
            ("testValueBlocksWhileUnfilled", testValueBlocksWhileUnfilled),
            ("testValueUnblocksWhenUnfilledIsFilled", testValueUnblocksWhenUnfilledIsFilled),
            ("testFill", testFill),
            ("testFillMultipleTimes", testFillMultipleTimes),
            ("testIsFilled", testIsFilled),
            ("testUponWithFilled", testUponWithFilled),
            ("testUponNotCalledWhileUnfilled", testUponNotCalledWhileUnfilled),
            ("testUponCalledWhenFilled", testUponCalledWhenFilled),
            ("testUponMainQueueCalledWhenFilled", testUponMainQueueCalledWhenFilled),
            ("testConcurrentUpon", testConcurrentUpon),
            ("testAnd", testAnd),
            ("testAllFilled", testAllFilled),
            ("testAllFilledEmptyCollection", testAllFilledEmptyCollection),
            ("testFirstFilled", testFirstFilled),
            ("testAllCopiesOfADeferredValueRepresentTheSameDeferredValue", testAllCopiesOfADeferredValueRepresentTheSameDeferredValue),
            ("testDeferredOptionalBehavesCorrectly", testDeferredOptionalBehavesCorrectly),
            ("testIsFilledCanBeCalledMultipleTimesNotFilled", testIsFilledCanBeCalledMultipleTimesNotFilled),
            ("testIsFilledCanBeCalledMultipleTimesWhenFilled", testIsFilledCanBeCalledMultipleTimesWhenFilled),
            ("testFillAndIsFilledPostcondition", testFillAndIsFilledPostcondition)
        ]

        #if os(OSX)
        || (os(iOS) && !(arch(i386) || arch(x86_64)))
        || (os(watchOS) && !(arch(i386) || arch(x86_64)))
        || (os(tvOS) && !arch(x86_64))
            let appleTests: [(String, (DeferredTests) -> () throws -> Void)] = [
                ("testAllCopiesOfADeferredValueRepresentTheSameDeferredValue", testAllCopiesOfADeferredValueRepresentTheSameDeferredValue),
                ("testThatMainThreadPostsUponWithUserInitiatedQoSClass", testThatMainThreadPostsUponWithUserInitiatedQoSClass),
                ("testThatLowerQoSPostsUponWithSameQoSClass", testThatLowerQoSPostsUponWithSameQoSClass)
            ]

            return universalTests + appleTests
        #else
            return universalTests
        #endif
    }

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDestroyedWithoutBeingFilled() {
        do {
            _ = Deferred<Int>()
        }
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()

        let expect = expectation(description: "value blocks while unfilled")
        afterDelay(upon: .global()) {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        let peek = deferred.waitShort()
        XCTAssertNil(peek)

        waitForExpectations()
    }

    func testPeek() {
        let d1 = Deferred<Int>()
        let d2 = Deferred(filledWith: 1)
        XCTAssertNil(d1.peek())
        XCTAssertEqual(d2.value, 1)
    }

    func testValueOnFilled() {
        let filled = Deferred(filledWith: 2)
        XCTAssertEqual(filled.value, 2)
    }

    func testValueBlocksWhileUnfilled() {
        let unfilled = Deferred<Int>()

        let expect = expectation(description: "value blocks while unfilled")
        DispatchQueue.global().async {
            XCTAssertNil(unfilled.wait(until: .now() + 2))
        }
        afterDelay { expect.fulfill() }
        waitForExpectations()
    }

    func testValueUnblocksWhenUnfilledIsFilled() {
        let d = Deferred<Int>()
        let expect = expectation(description: "value blocks until filled")
        DispatchQueue.global().async {
            XCTAssertEqual(d.value, 3)
            expect.fulfill()
        }
        afterDelay {
            d.fill(with: 3)
        }
        waitForExpectations()
    }

    func testFill() {
        let d = Deferred<Int>()
        d.fill(with: 1)
        XCTAssertEqual(d.value, 1)
    }

    func testFillMultipleTimes() {
        let d = Deferred(filledWith: 1)
        XCTAssertEqual(d.value, 1)
        XCTAssertFalse(d.fill(with: 2))
        XCTAssertEqual(d.value, 1)
    }

    func testIsFilled() {
        let d = Deferred<Int>()
        XCTAssertFalse(d.isFilled)

        let expect = expectation(description: "isFilled is true when filled")
        d.upon { _ in
            XCTAssertTrue(d.isFilled)
            expect.fulfill()
        }
        d.fill(with: 1)
        waitForExpectationsShort()
    }

    func testUponWithFilled() {
        let d = Deferred(filledWith: 1)

        for _ in 0 ..< 10 {
            let expect = expectation(description: "upon blocks called with correct value")
            d.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
        }

        waitForExpectations()
    }

    func testUponNotCalledWhileUnfilled() {
        let d = Deferred<Int>()

        d.upon { _ in
            XCTFail("unexpected upon block call")
        }

        let expect = expectation(description: "upon blocks not called while deferred is unfilled")
        afterDelay {
            expect.fulfill()
        }

        waitForExpectations()
    }

    func testUponCalledWhenFilled() {
        let d = Deferred<Int>()

        for _ in 0 ..< 10 {
            let expect = expectation(description: "upon blocks not called while deferred is unfilled")
            d.upon { value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(d.value, value)
                expect.fulfill()
            }
        }

        d.fill(with: 1)

        waitForExpectations()
    }

    func testUponMainQueueCalledWhenFilled() {
        let d = Deferred<Int>()

        let expectation = self.expectation(description: "upon block called on main queue")
        d.upon(.main) { value in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            XCTAssertTrue(Thread.isMainThread)
            #else
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            XCTAssertEqual(value, 1)
            XCTAssertEqual(d.value, 1)
            expectation.fulfill()
        }

        d.fill(with: 1)
        waitForExpectationsShort()
    }

    func testConcurrentUpon() {
        let d = Deferred<Int>()
        let queue = DispatchQueue.global()

        // upon with an unfilled deferred appends to an internal array (protected by a write lock)
        // spin up a bunch of these in parallel...
        for i in 0 ..< 32 {
            let expectUponCalled = expectation(description: "upon block \(i)")
            queue.async {
                d.upon { _ in expectUponCalled.fulfill() }
            }
        }

        // ...then fill it (also in parallel)
        queue.async { d.fill(with: 1) }

        // ... and make sure all our upon blocks were called (i.e., the write lock protected access)
        waitForExpectations()
    }

    func testAnd() {
        let d1 = Deferred<Int>()
        let d2 = Deferred<String>()
        let both = d1.and(d2)

        XCTAssertFalse(both.isFilled)

        d1.fill(with: 1)
        XCTAssertFalse(both.isFilled)
        d2.fill(with: "foo")

        let expectation = self.expectation(description: "paired deferred should be filled")
        both.upon { _ in
            XCTAssert(d1.isFilled)
            XCTAssert(d2.isFilled)
            XCTAssertEqual(both.value.0, 1)
            XCTAssertEqual(both.value.1, "foo")
            expectation.fulfill()
        }

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

    /// Deferred values behave as values: All copies reflect the same value.
    /// The wrinkle of course is that the value might not be observable till a later
    /// date.
    func testAllCopiesOfADeferredValueRepresentTheSameDeferredValue() {
        let parent = Deferred<Int>()
        let child1 = parent
        let child2 = parent
        let allDeferreds = [parent, child1, child2]

        let anyValue = 42
        let expectedValues = [Int](repeating: anyValue, count: allDeferreds.count)

        let allShouldBeFulfilled = expectation(description: "filling any copy fulfills all")
        allDeferreds.allFilled().upon {
            [weak allShouldBeFulfilled] allValues in
            allShouldBeFulfilled?.fulfill()

            XCTAssertEqual(allValues, expectedValues, "all deferreds are the same value")
        }

        #if os(Linux)
        let randomIndex = Int(random() % allDeferreds.count)
        #else // arc4random_uniform is also available on BSD and Bionic
        let randomIndex = Int(arc4random_uniform(numericCast(allDeferreds.count)))
        #endif
        let oneOfTheDeferreds = allDeferreds[numericCast(randomIndex)]
        oneOfTheDeferreds.fill(with: anyValue)

        waitForExpectationsShort()
    }

    func testDeferredOptionalBehavesCorrectly() {
        let d = Deferred<Optional<Int>>(filledWith: .none)

        let beforeExpectation = expectation(description: "already filled with nil optional")
        d.upon {
            XCTAssert($0 == .none)
            beforeExpectation.fulfill()
        }

        XCTAssertFalse(d.fill(with: 42))

        let afterExpectation = expectation(description: "stays filled with same optional")
        d.upon {
            XCTAssert($0 == .none)
            afterExpectation.fulfill()
        }

        waitForExpectationsShort()
    }

    func testIsFilledCanBeCalledMultipleTimesNotFilled() {
        let d = Deferred<Int>()
        XCTAssertFalse(d.isFilled)
        XCTAssertFalse(d.isFilled)
        XCTAssertFalse(d.isFilled)
    }

    func testIsFilledCanBeCalledMultipleTimesWhenFilled() {
        let d = Deferred<Int>(filledWith: 42)
        XCTAssertTrue(d.isFilled)
        XCTAssertTrue(d.isFilled)
        XCTAssertTrue(d.isFilled)
    }

    // The QoS APIs do not behave as expected on the iOS Simulator, so we only
    // run these tests on real devices. This check isn't the most future-proof;
    // if there's ever another archiecture that runs the simulator, this will
    // need to be modified.
    #if os(OSX)
    || (os(iOS) && !(arch(i386) || arch(x86_64)))
    || (os(watchOS) && !(arch(i386) || arch(x86_64)))
    || (os(tvOS) && !arch(x86_64))

    func testThatMainThreadPostsUponWithUserInitiatedQoSClass() {
        let d = Deferred<Int>()

        let expectedQos = DispatchQoS.QoSClass(rawValue: qos_class_main())
        var uponQos: DispatchQoS.QoSClass?
        let expectation = self.expectation(description: "deferred upon blocks get called")

        d.upon { [weak expectation] _ in
            uponQos = DispatchQoS.QoSClass(rawValue: qos_class_self())
            expectation?.fulfill()
        }

        d.fill(with: 42)

        waitForExpectationsShort()
        XCTAssertNotNil(uponQos)
        XCTAssertEqual(uponQos, expectedQos)
    }

    func testThatLowerQoSPostsUponWithSameQoSClass() {
        let expectedQos = DispatchQoS.QoSClass.utility

        let d = Deferred<Int>()
        let q = DispatchQueue.global(qos: expectedQos)

        var uponQos: DispatchQoS.QoSClass?
        let expectation = self.expectation(description: "deferred upon blocks get called")

        d.upon(q) { [weak expectation] _ in
            uponQos = DispatchQoS.QoSClass(rawValue: qos_class_self())
            expectation?.fulfill()
        }

        d.fill(with: 42)

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotNil(uponQos)
        XCTAssertEqual(uponQos, expectedQos)
    }

    #endif // end QoS tests that require a real device

    func testFillAndIsFilledPostcondition() {
        let deferred = Deferred<Int>()
        XCTAssertFalse(deferred.isFilled)
        deferred.fill(with: 42)
        XCTAssertNotNil(deferred.peek())
        XCTAssertTrue(deferred.isFilled)
        XCTAssertNotNil(deferred.wait(until: .now()))
        XCTAssertNotNil(deferred.waitShort())  // pass
    }

}
