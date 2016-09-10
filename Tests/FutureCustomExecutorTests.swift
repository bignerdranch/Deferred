//
//  FutureCustomExecutorTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/10/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest
import Deferred

class FutureCustomExecutorTests: CustomExecutorTestCase {
    func testUpon() {
        let d = Deferred<Void>()

        let expect = expectation(description: "upon block called when deferred is filled")
        d.upon(executor) { _ in
            expect.fulfill()
        }

        d.fill(())

        waitForExpectations()
        assertExecutorCalled(1)
    }

    func testMap() {
        let marker = Deferred<Void>()
        let testValue = 42
        let mapped = marker.map(upon: executor) { testValue }

        let expect = expectation(description: "upon block called when deferred is filled")
        mapped.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(())

        waitForExpectations()
        assertExecutorCalled(2)
    }

    // Should this be promoted to an initializer on Future?
    private func delay<Value>(_ value: @autoclosure @escaping(Void) -> Value) -> Future<Value> {
        let d = Deferred<Value>()
        afterDelay {
            d.fill(value())
        }
        return Future(d)
    }

    func testFlatMap() {
        let marker = Deferred<Void>()
        let testValue = 42
        let flattened = marker.flatMap(upon: executor) { _ in self.delay(testValue) }

        let expect = expectation(description: "upon block called when deferred is filled")
        flattened.upon(executor) {
            XCTAssertEqual($0, testValue)
            expect.fulfill()
        }

        marker.fill(())

        waitForExpectations()
        assertExecutorCalled(3)
    }

}
