//
//  TaskGroupTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 8/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class TaskGroupTests: XCTestCase {
    static var allTests: [(String, (TaskGroupTests) -> () throws -> Void)] {
        return [
            ("testThatAllCompleteTaskWaitsForAllAccumulatedTasks", testThatAllCompleteTaskWaitsForAllAccumulatedTasks),
        ]
    }

    private let queue = DispatchQueue(label: "TaskGroupTests", attributes: .concurrent)
    private var accumulator: TaskGroup!

    override func setUp() {
        super.setUp()
        accumulator = TaskGroup()
    }

    override func tearDown() {
        accumulator = nil
        super.tearDown()
    }

    func testThatAllCompleteTaskWaitsForAllAccumulatedTasks() {
        let numTasks = 20
        var tasks = [Task<Void>]()
        for i in 0 ..< numTasks {
            let deferred = Deferred<Task<Void>.Result>()
            let task = Task<Void>(deferred, cancellation: nil)
            tasks.append(task)
            accumulator.include(task)

            afterDelay {
                // success/failure should be ignored by TaskGroup, so try both!
                if i % 2 == 0 {
                    deferred.fill(with: .success(()))
                } else {
                    deferred.fill(with: .failure(TestError.first))
                }
            }
        }

        let expectation = self.expectation(description: "allCompleteTask finished")
        accumulator.completed().upon(queue) { [weak expectation] _ in
            for task in tasks {
                XCTAssertNotNil(task.wait(until: .distantFuture))
            }

            expectation?.fulfill()
        }

        waitForExpectations()
    }
}
