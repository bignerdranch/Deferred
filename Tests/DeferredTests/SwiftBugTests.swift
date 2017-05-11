//
//  SwiftBugTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 11/16/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest

@testable import Deferred

class SwiftBugTests: XCTestCase {
    static var allTests: [(String, (SwiftBugTests) -> () throws -> Void)] {
        return [
            ("testIdAsAnyDictionaryDowncast", testIdAsAnyDictionaryDowncast),
            ("testIdAsAnyArrayDowncast", testIdAsAnyArrayDowncast)
        ]
    }

    // #150: In Swift 3.0 ..< 3.0.1, Swift collections have some trouble round-
    // tripping through id-as-Any using `as?`. (SR-????)
    func testIdAsAnyDictionaryDowncast() {
        let deferred = Deferred<[SomeMultipayloadEnum: SomeMultipayloadEnum]>()

        let keys: [SomeMultipayloadEnum] = [ .one, .two("foo"), .three(42) ]

        let toBeFilledWith: [SomeMultipayloadEnum: SomeMultipayloadEnum] = [
            keys[0]: .two("one"),
            keys[1]: .two("two"),
            keys[2]: .two("three"),
        ]

        let expect = expectation(description: "upon is called with correct values")
        deferred.upon { (dict) in
            XCTAssertEqual(dict, toBeFilledWith)
            expect.fulfill()
        }

        deferred.fill(with: toBeFilledWith)
        waitForExpectationsShort()
    }

    // Variant of #150: In Swift 3.0 ..< 3.0.1, Swift collections have some
    // trouble round- tripping through id-as-Any using `as!`. (SR-2490)
    func testIdAsAnyArrayDowncast() {
        let deferred = Deferred<[SomeMultipayloadEnum]>()

        let toBeFilledWith: [SomeMultipayloadEnum] = [ .one, .two("foo"), .three(42) ]

        let expect = expectation(description: "upon is called with correct values")
        deferred.upon { (array) in
            XCTAssertEqual(array.count, toBeFilledWith.count)
            expect.fulfill()
        }

        deferred.fill(with: toBeFilledWith)
        waitForExpectationsShort()
    }
}
