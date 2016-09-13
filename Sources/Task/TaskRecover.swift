//
//  TaskRecover.swift
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
    /// failed task's error.
    ///
    /// `recover` submits the `transform` to the `executor` once the task fails.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func recover(upon executor: ExecutorType, _ transform: @escaping(Error) throws -> SuccessValue) -> Task<SuccessValue> {
        let progress = extendedProgress(byUnitCount: 1)
        let future: Future<TaskResult<SuccessValue>> = map(upon: executor) { (result) in
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }

            return TaskResult {
                try result.withValues(ifSuccess: { $0 }, ifFailure: { try transform($0) })
            }
        }

        return Task(future: future, progress: progress)
    }
}
