//
//  FilledDeferredTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/30/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Deferred

class FilledDeferredTests: XCTestCase {
    static let allTests: [(String, (FilledDeferredTests) -> () throws -> Void)] = [
        ("testPeek", testPeek),
        ("testWaitWithTimeout", testWaitWithTimeout),
        ("testValue", testValue),
        ("testCannotFillMultipleTimes", testCannotFillMultipleTimes),
        ("testIsFilled", testIsFilled),
        ("testUpon", testUpon),
        ("testUponMainQueueCalled", testUponMainQueueCalled),
        ("testConcurrentUpon", testConcurrentUpon),
        ("testAllCopiesOfADeferredValueRepresentTheSameDeferredValue", testAllCopiesOfADeferredValueRepresentTheSameDeferredValue),
        ("testDeferredOptionalBehavesCorrectly", testDeferredOptionalBehavesCorrectly),
        ("testIsFilledCanBeCalledMultipleTimesWhenFilled", testIsFilledCanBeCalledMultipleTimesWhenFilled),
        ("testDebugDescription", testDebugDescription),
        ("testDebugDescriptionWhenValueIsVoid", testDebugDescriptionWhenValueIsVoid),
        ("testReflection", testReflection),
        ("testReflectionFilledWhenValueIsVoid", testReflectionFilledWhenValueIsVoid)
    ]

    func testPeek() {
        let filled = Deferred<Int>(filledWith: 1)
        XCTAssertEqual(filled.peek(), 1)
    }

    func testWaitWithTimeout() {
        let filled = Deferred<Int>(filledWith: 42)
        XCTAssertNotNil(filled.shortWait())
    }

    func testValue() {
        let filled = Deferred<Int>(filledWith: 2)
        XCTAssertEqual(filled.value, 2)
    }

    func testCannotFillMultipleTimes() {
        let filled = Deferred<Int>(filledWith: 1)
        XCTAssertFalse(filled.fill(with: 2))
        XCTAssertEqual(filled.value, 1)
    }

    func testIsFilled() {
        let filled = Deferred<Int>(filledWith: 1)
        XCTAssertTrue(filled.isFilled)
    }

    func testUpon() {
        let filled = Deferred<Int>(filledWith: 1)

        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) not called while deferred is unfilled")
            filled.upon { value in
                XCTAssertEqual(value, 1)
                expect.fulfill()
            }
            return expect
        }

        shortWait(for: allExpectations)
    }

    func testUponMainQueueCalled() {
        let filled = Deferred<Int>(filledWith: 1)

        let expect = expectation(description: "upon block called on main queue")
        filled.upon(.main) { value in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            XCTAssertTrue(Thread.isMainThread)
            #else
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            XCTAssertEqual(value, 1)
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }

    func testConcurrentUpon() {
        let filled = Deferred<Int>(filledWith: 1)
        let queue = DispatchQueue.global()

        // spin up a bunch of these in parallel...
        let allExpectations = (0 ..< 32).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block \(iteration)")
            queue.async {
                filled.upon { _ in
                    expect.fulfill()
                }
            }
            return expect
        }

        // ... and make sure all our upon blocks were called (i.e., the write lock protected access)
        shortWait(for: allExpectations)
    }

    /// Deferred values behave as values: All copies reflect the same value.
    /// The wrinkle of course is that the value might not be observable till a later
    /// date.
    func testAllCopiesOfADeferredValueRepresentTheSameDeferredValue() {
        let anyValue = 42

        let parent = Deferred(filledWith: anyValue)
        let child1 = parent
        let child2 = parent
        let allDeferreds = [parent, child1, child2]

        let expectedValues = Array(repeating: anyValue, count: allDeferreds.count)

        let expect = expectation(description: "filling any copy fulfills all")
        allDeferreds.allFilled().upon { (allValues) in
            XCTAssertEqual(allValues, expectedValues, "all deferreds are the same value")
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }

    func testDeferredOptionalBehavesCorrectly() {
        let filled = Deferred<Int?>(filledWith: nil)

        let beforeExpect = expectation(description: "already filled with nil optional")
        filled.upon { (value) in
            XCTAssertNil(value)
            beforeExpect.fulfill()
        }

        XCTAssertFalse(filled.fill(with: 42))

        let afterExpect = expectation(description: "stays filled with same optional")
        filled.upon { (value) in
            XCTAssertNil(value)
            afterExpect.fulfill()
        }

        shortWait(for: [ beforeExpect, afterExpect ])
    }

    func testIsFilledCanBeCalledMultipleTimesWhenFilled() {
        let filled = Deferred<Int>(filledWith: 42)

        for _ in 0 ..< 5 {
            XCTAssertTrue(filled.isFilled)
        }
    }

    func testDebugDescription() {
        let filled = Deferred<Int>(filledWith: 42)

        XCTAssertEqual("\(filled)", "Deferred(42)")
    }

    func testDebugDescriptionWhenValueIsVoid() {
        let filled = Deferred<Void>(filledWith: ())

        XCTAssertEqual("\(filled)", "Deferred(filled)")
    }

    func testReflection() {
        let filled = Deferred<Int>(filledWith: 42)

        let magicMirror = Mirror(reflecting: filled)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? Int, 42)
    }

    func testReflectionFilledWhenValueIsVoid() {
        let filled = Deferred<Void>(filledWith: ())

        let magicMirror = Mirror(reflecting: filled)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, true)
    }
}
