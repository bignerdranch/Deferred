//
//  FutureCustomExecutorTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 4/10/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest
@testable import Deferred

class FutureCustomExecutorTests: CustomExecutorTestCase {
    static var allTests: [(String, (FutureCustomExecutorTests) -> () throws -> Void)] {
        return [
            ("testUpon", testUpon),
            ("testMap", testMap),
            ("testAndThen", testAndThen),
        ]
    }

    func testUpon() {
        let d = Deferred<Void>()

        let expect = expectation(description: "upon block called when deferred is filled")
        d.upon(executor) { _ in
            expect.fulfill()
        }

        d.fill(with: ())

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testMap() {
        let marker = Deferred<Void>()
        let testValue = 42
        let mapped = marker.map(upon: executor) { _ in testValue }

        let expect = expectation(description: "upon block called when deferred is filled")
        mapped.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(with: ())

        waitForExpectations()
        assertExecutorCalled(2)
    }

    // Should this be promoted to an initializer on Future?
    private func delay<Value>(_ value: @autoclosure @escaping() -> Value) -> Future<Value> {
        let d = Deferred<Value>()
        afterDelay {
            d.fill(with: value())
        }
        return Future(d)
    }

    func testAndThen() {
        let marker = Deferred<Void>()
        let testValue = 42
        let flattened = marker.andThen(upon: executor) { _ in self.delay(testValue) }

        let expect = expectation(description: "upon block called when deferred is filled")
        flattened.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(with: ())

        waitForExpectations()
        assertExecutorCalled(3)
    }
}
