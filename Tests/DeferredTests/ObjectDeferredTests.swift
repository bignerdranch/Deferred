//
//  ObjectDeferredTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/30/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Deferred

// swiftlint:disable type_body_length

class ObjectDeferredTests: XCTestCase {
    static let allTests: [(String, (ObjectDeferredTests) -> () throws -> Void)] = [
        ("testPeekWhenUnfilled", testPeekWhenUnfilled),
        ("testPeekWhenFilled", testPeekWhenFilled),
        ("testWaitWithTimeout", testWaitWithTimeout),
        ("testWaitBlocksWhileUnfilled", testWaitBlocksWhileUnfilled),
        ("testValueUnblocksWhenUnfilledIsFilled", testValueUnblocksWhenUnfilledIsFilled),
        ("testFill", testFill),
        ("testCannotFillMultipleTimes", testCannotFillMultipleTimes),
        ("testIsFilled", testIsFilled),
        ("testUponCalledWhenFilled", testUponCalledWhenFilled),
        ("testUponCalledIfAlreadyFilled", testUponCalledIfAlreadyFilled),
        ("testUponNotCalledWhileUnfilled", testUponNotCalledWhileUnfilled),
        ("testUponMainQueueCalledWhenFilled", testUponMainQueueCalledWhenFilled),
        ("testConcurrentUpon", testConcurrentUpon),
        ("testAllCopiesOfADeferredValueRepresentTheSameDeferredValue", testAllCopiesOfADeferredValueRepresentTheSameDeferredValue),
        ("testDeferredOptionalBehavesCorrectly", testDeferredOptionalBehavesCorrectly),
        ("testIsFilledCanBeCalledMultipleTimesNotFilled", testIsFilledCanBeCalledMultipleTimesNotFilled),
        ("testIsFilledCanBeCalledMultipleTimesWhenFilled", testIsFilledCanBeCalledMultipleTimesWhenFilled),
        ("testSimultaneousFill", testSimultaneousFill),
        ("testDebugDescriptionUnfilled", testDebugDescriptionUnfilled),
        ("testDebugDescriptionFilled", testDebugDescriptionFilled),
        ("testReflectionUnfilled", testReflectionUnfilled),
        ("testReflectionFilled", testReflectionFilled)
    ]

    private final class TestObject: Equatable {
        static func == (lhs: TestObject, rhs: TestObject) -> Bool {
            return lhs === rhs
        }
    }

    func testPeekWhenUnfilled() {
        let unfilled = Deferred<TestObject>()
        XCTAssertNil(unfilled.peek())
    }

    func testPeekWhenFilled() {
        let toBeFilled = Deferred<TestObject>()
        let result = TestObject()
        toBeFilled.fill(with: result)
        XCTAssertEqual(toBeFilled.peek(), result)
    }

    func testWaitWithTimeout() {
        let toBeFilled = Deferred<TestObject>()

        let expect = expectation(description: "value blocks while unfilled")
        afterShortDelay {
            toBeFilled.fill(with: TestObject())
            expect.fulfill()
        }

        XCTAssertNil(toBeFilled.shortWait())

        shortWait(for: [ expect ])
    }

    func testWaitBlocksWhileUnfilled() {
        let unfilled = Deferred<TestObject>()
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
        let deferred = Deferred<TestObject>()
        let result = TestObject()
        let expect = expectation(description: "value blocks until filled")

        DispatchQueue.global().async {
            XCTAssertEqual(deferred.value, result)
            expect.fulfill()
        }

        afterShortDelay {
            deferred.fill(with: result)
        }

        shortWait(for: [ expect ])
    }

    func testFill() {
        let toBeFilled = Deferred<TestObject>()
        let result = TestObject()
        toBeFilled.fill(with: result)
        XCTAssertEqual(toBeFilled.value, result)
    }

    func testCannotFillMultipleTimes() {
        let toBeFilledRepeatedly = Deferred<TestObject>()

        let firstResult = TestObject()
        toBeFilledRepeatedly.fill(with: firstResult)
        XCTAssertEqual(toBeFilledRepeatedly.value, firstResult)

        let secondResult = TestObject()
        XCTAssertFalse(toBeFilledRepeatedly.fill(with: secondResult))

        XCTAssertEqual(toBeFilledRepeatedly.value, firstResult)
    }

    func testIsFilled() {
        let toBeFilled = Deferred<TestObject>()
        XCTAssertFalse(toBeFilled.isFilled)

        let expect = expectation(description: "isFilled is true when filled")
        toBeFilled.upon { _ in
            XCTAssertTrue(toBeFilled.isFilled)
            expect.fulfill()
        }

        toBeFilled.fill(with: TestObject())
        shortWait(for: [ expect ])
    }

    func testUponCalledWhenFilled() {
        let deferred = Deferred<TestObject>()
        let result = TestObject()

        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) not called while deferred is unfilled")
            deferred.upon { value in
                XCTAssertEqual(value, result)
                expect.fulfill()
            }
            return expect
        }

        deferred.fill(with: result)
        shortWait(for: allExpectations)
    }

    func testUponCalledIfAlreadyFilled() {
        let toBeFilled = Deferred<TestObject>()
        let result = TestObject()
        toBeFilled.fill(with: result)

        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block #\(iteration) called with correct value")
            toBeFilled.upon { value in
                XCTAssertEqual(value, result)
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
            let unfilled = Deferred<TestObject>()
            for _ in 0 ..< 5 {
                 unfilled.upon { (value) in
                    XCTFail("Unexpected upon handler call with \(value) with capture \(object)")
                }
            }
            expect = expectation(deallocationOf: object)
        }
        shortWait(for: [ expect ])
    }

    func testUponMainQueueCalledWhenFilled() {
        let deferred = Deferred<TestObject>()
        let result = TestObject()

        let expect = expectation(description: "upon block called on main queue")
        deferred.upon(.main) { value in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            XCTAssertTrue(Thread.isMainThread)
            #else
            dispatchPrecondition(condition: .onQueue(.main))
            #endif
            XCTAssertEqual(value, result)
            expect.fulfill()
        }

        deferred.fill(with: result)
        shortWait(for: [ expect ])
    }

    func testConcurrentUpon() {
        let deferred = Deferred<TestObject>()
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
            deferred.fill(with: TestObject())
        }

        // ... and make sure all our upon blocks were called (i.e., the write lock protected access)
        shortWait(for: allExpectations)
    }

    /// Deferred values behave as references: All copies reflect the same value.
    /// The wrinkle, of course, is that the value might not be observable until
    /// a later date.
    func testAllCopiesOfADeferredValueRepresentTheSameDeferredValue() {
        let parent = Deferred<TestObject>()
        let child1 = parent
        let child2 = parent
        let allDeferreds = [parent, child1, child2]

        let anyValue = TestObject()
        let expectedValues = Array(repeating: anyValue, count: allDeferreds.count)

        let expect = expectation(description: "filling any copy fulfills all")
        allDeferreds.allFilled().upon { (allValues) in
            XCTAssertEqual(allValues, expectedValues, "all deferreds are the same value")
            expect.fulfill()
        }

        allDeferreds.randomElement()?.fill(with: anyValue)

        shortWait(for: [ expect ])
    }

    func testDeferredOptionalBehavesCorrectly() {
        let toBeFilled = Deferred<TestObject?>()
        toBeFilled.fill(with: nil)

        let beforeExpect = expectation(description: "already filled with nil optional")
        toBeFilled.upon { (value) in
            XCTAssertNil(value)
            beforeExpect.fulfill()
        }

        XCTAssertFalse(toBeFilled.fill(with: TestObject()))

        let afterExpect = expectation(description: "stays filled with same optional")
        toBeFilled.upon { (value) in
            XCTAssertNil(value)
            afterExpect.fulfill()
        }

        shortWait(for: [ beforeExpect, afterExpect ])
    }

    func testIsFilledCanBeCalledMultipleTimesNotFilled() {
        let unfilled = Deferred<TestObject>()

        for _ in 0 ..< 5 {
            XCTAssertFalse(unfilled.isFilled)
        }
    }

    func testIsFilledCanBeCalledMultipleTimesWhenFilled() {
        let toBeFilled = Deferred<TestObject>()
        toBeFilled.fill(with: TestObject())

        for _ in 0 ..< 5 {
            XCTAssertTrue(toBeFilled.isFilled)
        }
    }

    func testSimultaneousFill() {
        let deferred = Deferred<TestObject>()
        let startGroup = DispatchGroup()
        startGroup.enter()
        let finishGroup = DispatchGroup()

        let expect = expectation(description: "isFilled is true when filled")
        deferred.upon { _ in
            expect.fulfill()
        }

        for _ in 0 ..< 10 {
            DispatchQueue.global().async(group: finishGroup) {
                XCTAssertEqual(startGroup.wait(timeout: .distantFuture), .success)
                deferred.fill(with: TestObject())
            }
        }

        startGroup.leave()
        XCTAssertEqual(finishGroup.wait(timeout: .distantFuture), .success)
        shortWait(for: [ expect ])
    }

    func testDebugDescriptionUnfilled() {
        let unfilled = Deferred<TestObject>()

        let debugDescription = String(reflecting: unfilled)
        XCTAssertEqual(debugDescription, "Deferred(not filled)")
    }

    func testDebugDescriptionFilled() {
        let toBeFilled = Deferred<TestObject>()
        let result = TestObject()
        toBeFilled.fill(with: result)

        let debugDescription = String(reflecting: toBeFilled)
        XCTAssertEqual(debugDescription, "Deferred(\(result))")
    }

    func testReflectionUnfilled() {
        let unfilled = Deferred<TestObject>()

        let magicMirror = Mirror(reflecting: unfilled)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isFilled") as? Bool, false)
    }

    func testReflectionFilled() {
        let toBeFilled = Deferred<TestObject>()
        let result = TestObject()
        toBeFilled.fill(with: result)

        let magicMirror = Mirror(reflecting: toBeFilled)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? TestObject, result)
    }
}
