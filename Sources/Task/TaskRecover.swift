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
    private func commonBody(for transform: @escaping(Error) throws -> SuccessValue) -> (Progress, (Result) -> TaskResult<SuccessValue>) {
        let progress = extendedProgress(byUnitCount: 1)
        return (progress, { (result) in
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }

            return TaskResult {
                try result.withValues(ifSuccess: { $0 }, ifFailure: { try transform($0) })
            }
        })
    }

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
        let (progress, body) = commonBody( for: transform)
        let future = map(upon: executor, body)
        return Task(future: future, progress: progress)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// failed task's error.
    ///
    /// `recover` executes the `transform` asynchronously once the task fails.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func recover(upon queue: DispatchQueue, _ transform: @escaping(Error) throws -> SuccessValue) -> Task<SuccessValue> {
        let (progress, body) = commonBody(for: transform)
        let future = map(upon: queue, body)
        return Task(future: future, progress: progress)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// failed task's error.
    ///
    /// `recover` executes the `transform` in the background once the task fails.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(_:)
    public func recover(_ transform: @escaping(Error) throws -> SuccessValue) -> Task<SuccessValue> {
        let (progress, body) = commonBody(for: transform)
        let future = map(body)
        return Task(future: future, progress: progress)
    }
}
