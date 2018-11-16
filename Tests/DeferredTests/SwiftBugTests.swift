//
//  SwiftBugTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 11/16/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

import Deferred

class SwiftBugTests: XCTestCase {
    static let allTests: [(String, (SwiftBugTests) -> () throws -> Void)] = [
        ("testIdAsAnyDictionaryDowncast", testIdAsAnyDictionaryDowncast),
        ("testIdAsAnyArrayDowncast", testIdAsAnyArrayDowncast)
    ]

    private enum SomeMultipayloadEnum: Hashable {
        case one
        case two(String)
        case three(Double)

        var hashValue: Int {
            switch self {
            case .one:
                return 1
            case .two(let str):
                return str.hashValue
            case .three(let obj):
                return obj.hashValue
            }
        }

        static func == (lhs: SomeMultipayloadEnum, rhs: SomeMultipayloadEnum) -> Bool {
            switch (lhs, rhs) {
            case (.one, .one):
                return true
            case let (.two(lhs), .two(rhs)):
                return lhs == rhs
            case let (.three(lhs), .three(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // #150: In Swift 3.0 ..< 3.0.1, Swift collections have some trouble round-
    // tripping through id-as-Any using `as?`. (SR-????)
    func testIdAsAnyDictionaryDowncast() {
        let deferred = Deferred<[SomeMultipayloadEnum: SomeMultipayloadEnum]>()

        let keys: [SomeMultipayloadEnum] = [ .one, .two("foo"), .three(42) ]

        let toBeFilledWith: [SomeMultipayloadEnum: SomeMultipayloadEnum] = [
            keys[0]: .two("one"),
            keys[1]: .two("two"),
            keys[2]: .two("three")
        ]

        let expect = expectation(description: "upon is called with correct values")
        deferred.upon { (dict) in
            XCTAssertEqual(dict, toBeFilledWith)
            expect.fulfill()
        }

        deferred.fill(with: toBeFilledWith)
        wait(for: [ expect ], timeout: shortTimeout)
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
        wait(for: [ expect ], timeout: shortTimeout)
    }
}
