//
//  TaskFlatMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Foundation

extension Task {
    private func commonBody<NewTask: FutureType where NewTask.Value: ResultType>(for startNextTask: SuccessValue throws -> NewTask) -> (NSProgress, (Result) -> Task<NewTask.Value.Value>) {
        let progress = extendedProgress(byUnitCount: 1)
        return (progress, { (result) in
            do {
                let value = try result.extract()

                // We want to become the thread-local progress, but we don't
                // want to consume units; we may not attach newTask.progress to
                // the root progress until after the scope ends.
                progress.becomeCurrentWithPendingUnitCount(0)
                defer { progress.resignCurrent() }

                // Attempt to create and wrap the next task. Task's own progress
                // wrapper logic takes over at this point.
                let newTask = try startNextTask(value)
                return Task<NewTask.Value.Value>(newTask)
            } catch {
                // Failure case behaves just like map: just error passthrough.
                progress.becomeCurrentWithPendingUnitCount(1)
                defer { progress.resignCurrent() }
                return Task<NewTask.Value.Value>(error: error)
            }
        })
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the recieving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` submits `startNextTask` to `executor`
    /// once the task completes successfully.
    /// - seealso: FutureType.flatMap(upon:_:)
    public func flatMap<NewTask: FutureType where NewTask.Value: ResultType>(upon executor: ExecutorType, _ startNextTask: SuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let (progress, body) = commonBody(for: startNextTask)
        let future = flatMap(upon: executor, body)
        return Task<NewTask.Value.Value>(future: future, progress: progress)
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` executes `startNextTask`
    /// asynchronously once the task completes successfully.
    /// - seealso: flatMap(upon:_:)
    /// - seealso: FutureType.flatMap(upon:_:)
    public func flatMap<NewTask: FutureType where NewTask.Value: ResultType>(upon queue: dispatch_queue_t, _ startNextTask: SuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let (progress, body) = commonBody(for: startNextTask)
        let future = flatMap(upon: queue, body)
        return Task<NewTask.Value.Value>(future: future, progress: progress)
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` executes `startNextTask` in the
    /// background once the task completes successfully.
    /// - seealso: flatMap(upon:_:)
    /// - seealso: FutureType.flatMap(_:)
    public func flatMap<NewTask: FutureType where NewTask.Value: ResultType>(startNextTask: SuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let (progress, body) = commonBody(for: startNextTask)
        let future = flatMap(body)
        return Task<NewTask.Value.Value>(future: future, progress: progress)
    }
}
