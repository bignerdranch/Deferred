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

        let expect = expectationWithDescription("value blocks while unfilled")
        afterDelay(1, upon: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            deferred.fill(42)
            expect.fulfill()
        }

        let peek: ()? = future.wait(.Interval(0.5))
        XCTAssertNil(peek)

        waitForExpectationsWithTimeout(1.5, handler: nil)
    }

    func testIgnoredUponCalledWhenFilled() {
        let d = Deferred<Int>()
        future = d.ignored()

        for _ in 0 ..< 10 {
            let expect = expectationWithDescription("upon blocks not called while deferred is unfilled")
            future.upon {
                XCTAssertEqual(d.value, 1)
                expect.fulfill()
            }
        }

        d.fill(1)

        waitForExpectationsWithTimeout(1, handler: nil)
    }

}
