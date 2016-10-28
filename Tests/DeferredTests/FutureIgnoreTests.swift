//
//  FutureIgnoreTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred
#if SWIFT_PACKAGE
@testable import TestSupport
#endif

class FutureIgnoreTests: XCTestCase {
    static var allTests: [(String, (FutureIgnoreTests) -> () throws -> Void)] {
        return [
            ("testWaitWithTimeout", testWaitWithTimeout),
            ("testIgnoredUponCalledWhenFilled", testIgnoredUponCalledWhenFilled),
        ]
    }

    var future: Future<Void>!

    override func tearDown() {
        future = nil

        super.tearDown()
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()
        future = deferred.ignored()

        let expect = expectation(description: "value blocks while unfilled")
        afterDelay(upon: .global()) {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        let peek: ()? = future.waitShort()
        XCTAssertNil(peek)

        waitForExpectations()
    }

    func testIgnoredUponCalledWhenFilled() {
        let d = Deferred<Int>()
        future = d.ignored()

        for _ in 0 ..< 10 {
            let expect = expectation(description: "upon blocks not called while deferred is unfilled")
            future.upon {
                XCTAssertEqual(d.value, 1)
                expect.fulfill()
            }
        }

        d.fill(with: 1)

        waitForExpectations()
    }
}
