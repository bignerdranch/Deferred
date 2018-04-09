//
//  DeferredTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Foundation

@testable import Deferred

// swiftlint:disable file_length
// swiftlint:disable type_body_length

class DeferredTests: XCTestCase {
    static let universalTests: [(String, (DeferredTests) -> () throws -> Void)] = [
        ("testPeekWhenUnfilled", testPeekWhenUnfilled),
        ("testPeekWhenFilled", testPeekWhenFilled),
        ("testWaitWithTimeout", testWaitWithTimeout),
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
        ("testAllCopiesOfADeferredValueRepresentTheSameDeferredValue", testAllCopiesOfADeferredValueRepresentTheSameDeferredValue),
        ("testDeferredOptionalBehavesCorrectly", testDeferredOptionalBehavesCorrectly),
        ("testIsFilledCanBeCalledMultipleTimesNotFilled", testIsFilledCanBeCalledMultipleTimesNotFilled),
        ("testIsFilledCanBeCalledMultipleTimesWhenFilled", testIsFilledCanBeCalledMultipleTimesWhenFilled),
        ("testFillAndIsFilledPostcondition", testFillAndIsFilledPostcondition),
        ("testSimultaneousFill", testSimultaneousFill),
        ("testDebugDescriptionUnfilled", testDebugDescriptionUnfilled),
        ("testDebugDescriptionFilled", testDebugDescriptionFilled),
        ("testDebugDescriptionFilledWhenValueIsVoid", testDebugDescriptionFilledWhenValueIsVoid),
        ("testReflectionUnfilled", testReflectionUnfilled),
        ("testReflectionFilled", testReflectionFilled),
        ("testReflectionFilledWhenValueIsVoid", testReflectionFilledWhenValueIsVoid)
    ]

    static var allTests: [(String, (DeferredTests) -> () throws -> Void)] {
        #if os(macOS) || (os(iOS) && !(arch(i386) || arch(x86_64))) || (os(watchOS) && !(arch(i386) || arch(x86_64))) || (os(tvOS) && !arch(x86_64))
            return universalTests + [
                ("testThatMainThreadPostsUponWithUserInitiatedQoSClass", testThatMainThreadPostsUponWithUserInitiatedQoSClass),
                ("testThatLowerQoSPostsUponWithSameQoSClass", testThatLowerQoSPostsUponWithSameQoSClass)
            ]
        #else
            return universalTests
        #endif
    }

    func testPeekWhenUnfilled() {
        let unfilled = Deferred<Int>()
        XCTAssertNil(unfilled.peek())
    }

    func testPeekWhenFilled() {
        let filled = Deferred(filledWith: 1)
        XCTAssertEqual(filled.peek(), 1)
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()

        let expect = expectation(description: "value blocks while unfilled")
        afterShortDelay {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        XCTAssertNil(deferred.shortWait())

        shortWait(for: [ expect ])
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

        afterShortDelay {
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }

    func testValueUnblocksWhenUnfilledIsFilled() {
        let deferred = Deferred<Int>()
        let expect = expectation(description: "value blocks until filled")

        DispatchQueue.global().async {
            XCTAssertEqual(deferred.value, 3)
            expect.fulfill()
        }

        afterShortDelay {
            deferred.fill(with: 3)
        }

        shortWait(for: [ expect ])
    }

    func testFill() {
        let toBeFilled = Deferred<Int>()
        toBeFilled.fill(with: 1)
        XCTAssertEqual(toBeFilled.value, 1)
    }

    func testFillMultipleTimes() {
        let toBeFilledRepeatedly = Deferred(filledWith: 1)
        XCTAssertEqual(toBeFilledRepeatedly.value, 1)
        XCTAssertFalse(toBeFilledRepeatedly.fill(with: 2))
        XCTAssertEqual(toBeFilledRepeatedly.value, 1)
    }

    func testIsFilled() {
        let toBeFilled = Deferred<Int>()
        XCTAssertFalse(toBeFilled.isFilled)

        let expect = expectation(description: "isFilled is true when filled")
        toBeFilled.upon { _ in
            XCTAssertTrue(toBeFilled.isFilled)
            expect.fulfill()
        }
        toBeFilled.fill(with: 1)
        shortWait(for: [ expect ])
    }

    func testUponWithFilled() {
        let deferred = Deferred(filledWith: 1)
        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) called with correct value")
            deferred.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
            return expect
        }
        shortWait(for: allExpectations)
    }

    func testUponNotCalledWhileUnfilled() {
        let expect: XCTestExpectation
        do {
            let object = NSObject()
            let deferred = Deferred<Int>()
            for _ in 0 ..< 5 {
                 deferred.upon { (value) in
                    XCTFail("Unexpected upon handler call with \(value) with capture \(object)")
                }
            }
            expect = expectation(deallocationOf: object)
        }
        shortWait(for: [ expect ])
    }

    func testUponCalledWhenFilled() {
        let deferred = Deferred<Int>()
        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) not called while deferred is unfilled")
            deferred.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
            return expect
        }

        deferred.fill(with: 1)
        shortWait(for: allExpectations)
    }

    func testUponMainQueueCalledWhenFilled() {
        let deferred = Deferred<Int>()

        let expect = expectation(description: "upon block called on main queue")
        deferred.upon(.main) { value in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            XCTAssertTrue(Thread.isMainThread)
            #else
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            XCTAssertEqual(value, 1)
            expect.fulfill()
        }

        deferred.fill(with: 1)
        shortWait(for: [ expect ])
    }

    func testConcurrentUpon() {
        let deferred = Deferred<Int>()
        let queue = DispatchQueue.global()

        // spin up a bunch of these in parallel...
        let allExpectations = (0 ..< 32).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block \(iteration)")
            queue.async {
                deferred.upon { _ in
                    expect.fulfill()
                }
            }
            return expect
        }

        // ...then fill it (also in parallel)
        queue.async {
            deferred.fill(with: 1)
        }

        // ... and make sure all our upon blocks were called (i.e., the write lock protected access)
        shortWait(for: allExpectations)
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

        let expect = expectation(description: "filling any copy fulfills all")
        allDeferreds.allFilled().upon { (allValues) in
            XCTAssertEqual(allValues, expectedValues, "all deferreds are the same value")
            expect.fulfill()
        }

        allDeferreds.random().fill(with: anyValue)

        shortWait(for: [ expect ])
    }

    func testDeferredOptionalBehavesCorrectly() {
        let deferred = Deferred<Int?>(filledWith: nil)

        let beforeExpect = expectation(description: "already filled with nil optional")
        deferred.upon { (value) in
            XCTAssertNil(value)
            beforeExpect.fulfill()
        }

        XCTAssertFalse(deferred.fill(with: 42))

        let afterExpect = expectation(description: "stays filled with same optional")
        deferred.upon { (value) in
            XCTAssertNil(value)
            afterExpect.fulfill()
        }

        shortWait(for: [ beforeExpect, afterExpect ])
    }

    func testIsFilledCanBeCalledMultipleTimesNotFilled() {
        let deferred = Deferred<Int>()
        XCTAssertFalse(deferred.isFilled)
        XCTAssertFalse(deferred.isFilled)
        XCTAssertFalse(deferred.isFilled)
    }

    func testIsFilledCanBeCalledMultipleTimesWhenFilled() {
        let deferred = Deferred<Int>(filledWith: 42)
        XCTAssertTrue(deferred.isFilled)
        XCTAssertTrue(deferred.isFilled)
        XCTAssertTrue(deferred.isFilled)
    }

    // The QoS APIs do not behave as expected on the iOS Simulator, so we only
    // run these tests on real devices. This check isn't the most future-proof;
    // if there's ever another archiecture that runs the simulator, this will
    // need to be modified.
    #if os(macOS) || (os(iOS) && !(arch(i386) || arch(x86_64))) || (os(watchOS) && !(arch(i386) || arch(x86_64))) || (os(tvOS) && !arch(x86_64))
    func testThatMainThreadPostsUponWithUserInitiatedQoSClass() {
        let deferred = Deferred<Int>()

        let expectedQoS = DispatchQoS.QoSClass(rawValue: qos_class_main())
        var uponQoS: DispatchQoS.QoSClass?
        let expect = expectation(description: "deferred upon blocks get called")

        deferred.upon { _ in
            uponQoS = DispatchQoS.QoSClass(rawValue: qos_class_self())
            expect.fulfill()
        }

        deferred.fill(with: 42)

        shortWait(for: [ expect ])
        XCTAssertEqual(uponQoS, expectedQoS)
    }

    func testThatLowerQoSPostsUponWithSameQoSClass() {
        let expectedQoS = DispatchQoS.QoSClass.utility

        let deferred = Deferred<Int>()
        let queue = DispatchQueue.global(qos: expectedQoS)

        var uponQoS: DispatchQoS.QoSClass?
        let expect = expectation(description: "deferred upon blocks get called")

        deferred.upon(queue) { _ in
            uponQoS = DispatchQoS.QoSClass(rawValue: qos_class_self())
            expect.fulfill()
        }

        deferred.fill(with: 42)

        shortWait(for: [ expect ])
        XCTAssertEqual(uponQoS, expectedQoS)
    }

    #endif // end QoS tests that require a real device

    func testFillAndIsFilledPostcondition() {
        let deferred = Deferred<Int>()
        XCTAssertFalse(deferred.isFilled)
        XCTAssertNil(deferred.peek())
        deferred.fill(with: 42)
        XCTAssertNotNil(deferred.peek())
        XCTAssertTrue(deferred.isFilled)
    }

    func testSimultaneousFill() {
        let deferred = Deferred<Int>()
        let startGroup = DispatchGroup()
        startGroup.enter()
        let finishGroup = DispatchGroup()

        let expect = expectation(description: "isFilled is true when filled")
        deferred.upon { _ in
            expect.fulfill()
        }

        for randomValue in 0 ..< (3 ..< 10).random() {
            DispatchQueue.global().async(group: finishGroup) {
                XCTAssertEqual(startGroup.wait(timeout: .distantFuture), .success)
                deferred.fill(with: randomValue)
            }
        }

        startGroup.leave()
        XCTAssertEqual(finishGroup.wait(timeout: .distantFuture), .success)
        shortWait(for: [ expect ])
    }

    func testDebugDescriptionUnfilled() {
        let deferred = Deferred<Int>()
        XCTAssertEqual("\(deferred)", "Deferred(not filled)")
    }

    func testDebugDescriptionFilled() {
        let deferred = Deferred<Int>(filledWith: 42)
        XCTAssertEqual("\(deferred)", "Deferred(42)")
    }

    func testDebugDescriptionFilledWhenValueIsVoid() {
        let deferred = Deferred<Void>(filledWith: ())
        XCTAssertEqual("\(deferred)", "Deferred(filled)")
    }

    func testReflectionUnfilled() {
        let deferred = Deferred<Int>()

        let magicMirror = Mirror(reflecting: deferred)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, false)
    }

    func testReflectionFilled() {
        let deferred = Deferred<Int>(filledWith: 42)

        let magicMirror = Mirror(reflecting: deferred)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? Int, 42)
    }

    func testReflectionFilledWhenValueIsVoid() {
        let deferred = Deferred<Void>(filledWith: ())

        let magicMirror = Mirror(reflecting: deferred)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, true)
    }
}
