//
//  IgnoringFutureTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred

class IgnoringFutureTests: XCTestCase {

    var future: IgnoringFuture<Deferred<Int>>!

    override func tearDown() {
        future = nil

        super.tearDown()
    }

    func testWaitWithTimeout() {
        let deferred = Deferred<Int>()
        future = deferred.ignored()

        let expect = expectation(description: "value blocks while unfilled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            deferred.fill(42)
            expect.fulfill()
        }

        let peek: ()? = future.wait(.interval(0.5))
        XCTAssertNil(peek)

        waitForExpectations(timeout: 1.5, handler: nil)
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

        d.fill(1)

        waitForExpectations(timeout: 1, handler: nil)
    }

}
