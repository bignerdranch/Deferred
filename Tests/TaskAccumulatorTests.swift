//
//  TaskAccumulatorTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 8/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Result
import Deferred
@testable import Task
#else
@testable import Deferred
#endif

class TaskAccumulatorTests: XCTestCase {

    private let queue = DispatchQueue(label: "TaskAccumulatorTests", attributes: .concurrent)
    private var accumulator: TaskAccumulator!

    override func setUp() {
        super.setUp()
        accumulator = TaskAccumulator()
    }

    override func tearDown() {
        accumulator = nil
        super.tearDown()
    }

    func testThatAllCompleteTaskWaitsForAllAccumulatedTasks() {
        let numTasks = 20
        var tasks = [Task<Void>]()
        for i in 0 ..< numTasks {
            let deferred = Deferred<TaskResult<Void>>()
            let task = Task<Void>(deferred, cancellation: { _ in })
            tasks.append(task)
            accumulator.accumulate(task)

            afterDelay {
                // success/failure should be ignored by TaskAccumulator, so try both!
                if i % 2 == 0 {
                    deferred.fill(.success(()))
                } else {
                    deferred.fill(.failure(Error.first))
                }
            }
        }

        let expectation = self.expectation(description: "allCompleteTask finished")
        accumulator.allCompleted().upon(queue) { [weak expectation] _ in
            for task in tasks {
                XCTAssertNotNil(task.wait(.forever))
            }

            expectation?.fulfill()
        }

        waitForExpectations()
    }
}
