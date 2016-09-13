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
    public func flatMap<NewTask: FutureType>(upon executor: ExecutorType, _ startNextTask: @escaping(SuccessValue) throws -> NewTask) -> Task<NewTask.Value.Value> where NewTask.Value: ResultType {
        let progress = extendedProgress(byUnitCount: 1)
        let future: Future<TaskResult<NewTask.Value.Value>> = flatMap(upon: executor) { (result) -> Task<NewTask.Value.Value> in
            do {
                let value = try result.extract()

                // We want to become the thread-local progress, but we don't
                // want to consume units; we may not attach newTask.progress to
                // the root progress until after the scope ends.
                progress.becomeCurrent(withPendingUnitCount: 0)
                defer { progress.resignCurrent() }

                // Attempt to create and wrap the next task. Task's own progress
                // wrapper logic takes over at this point.
                let newTask = try startNextTask(value)
                return Task<NewTask.Value.Value>(newTask)
            } catch {
                // Failure case behaves just like map: just error passthrough.
                progress.becomeCurrent(withPendingUnitCount: 1)
                defer { progress.resignCurrent() }
                return Task<NewTask.Value.Value>(error: error)
            }
        }

        return Task<NewTask.Value.Value>(future: future, progress: progress)
    }
}
