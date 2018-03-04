//
//  TaskGroupTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 8/18/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskGroupTests: XCTestCase {
    static let allTests: [(String, (TaskGroupTests) -> () throws -> Void)] = [
        ("testThatAllCompleteTaskWaitsForAllAccumulatedTasks", testThatAllCompleteTaskWaitsForAllAccumulatedTasks)
    ]

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

        let expect = expectation(description: "allCompleteTask finished")
        accumulator.completed().upon(queue) { _ in
            for task in tasks {
                XCTAssertNotNil(task.wait(until: .distantFuture))
            }

            expect.fulfill()
        }

        waitForExpectations()
    }
}
