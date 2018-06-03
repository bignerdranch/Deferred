//
//  FutureAsyncTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 6/3/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Deferred

class FutureAsyncTests: XCTestCase {
    static let allTests: [(String, (FutureAsyncTests) -> () throws -> Void)] = [
        ("testThatPeekingBeforeStartingReturnsNil", testThatPeekingBeforeStartingReturnsNil)
    ]

    private var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        queue = DispatchQueue(label: "FutureAsyncTests")
        queue.suspend()
    }

    override func tearDown() {
        queue = nil

        super.tearDown()
    }

    func testThatPeekingBeforeStartingReturnsNil() {
        let future = Future<Int>.async(upon: queue) { 1 }

        XCTAssertNil(future.peek())

        queue.resume()

        let expect = expectation(description: "future fulfils")
        future.upon(queue) { (result) in
            XCTAssertEqual(result, 1)
            expect.fulfill()
        }

        shortWait(for: [ expect ])
    }
}
