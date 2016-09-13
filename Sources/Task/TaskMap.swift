//
//  TaskMap.swift
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
    /// Returns a `Task` containing the result of mapping `transform` over the
    /// successful task's value.
    ///
    /// The `transform` is submitted to the `executor` once the task completes.
    ///
    /// Mapping a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewSuccessValue>(upon executor: ExecutorType, _ transform: @escaping(SuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let progress = extendedProgress(byUnitCount: 1)
        let future: Future<TaskResult<NewSuccessValue>> = map(upon: executor) { (result) in
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }

            return TaskResult {
                try transform(result.extract())
            }
        }

        return Task<NewSuccessValue>(future: future, progress: progress)
    }
}
