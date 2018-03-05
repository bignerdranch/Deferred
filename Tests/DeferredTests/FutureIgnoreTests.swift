//
//  FutureIgnoreTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

@testable import Deferred

class FutureIgnoreTests: XCTestCase {
    static let allTests: [(String, (FutureIgnoreTests) -> () throws -> Void)] = [
        ("testWaitWithTimeout", testWaitWithTimeout),
        ("testIgnoredUponCalledWhenFilled", testIgnoredUponCalledWhenFilled)
    ]

    var future: Future<Void>!

    override func tearDown() {
        future = nil

        super.tearDown()
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()
        future = deferred.ignored()

        let expect = expectation(description: "value blocks while unfilled")
        afterShortDelay {
            deferred.fill(with: 42)
            expect.fulfill()
        }

        XCTAssertNil(future.shortWait())

        shortWait(for: [ expect ])
    }

    func testIgnoredUponCalledWhenFilled() {
        let deferred = Deferred<Int>()
        future = deferred.ignored()

        let allExpectations = (0 ..< 10).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "upon block \(iteration) not called while deferred is unfilled")
            future.upon { _ in
                XCTAssertEqual(deferred.value, 1)
                expect.fulfill()
            }
            return expect
        }

        deferred.fill(with: 1)
        shortWait(for: allExpectations)
    }
}
