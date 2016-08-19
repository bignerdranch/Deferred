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

extension TaskType {
    private typealias SuccessValue = Value.Value
    private func commonBody<NewSuccessValue>(for transform: Value.Value throws -> NewSuccessValue) -> (NSProgress, (Value) -> TaskResult<NewSuccessValue>) {
        return extendingTask(unitCount: 1) { (result) in
            TaskResult {
                try transform(result.extract())
            }
        }
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value.
    ///
    /// The `transform` is submitted to the `executor` once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewSuccessValue>(upon executor: ExecutorType, _ transform: SuccessValue throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let (progress, body) = commonBody(for: transform)
        let future = map(upon: executor, body)
        return Task(future: future, progress: progress)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value
    ///
    /// The `transform` is submitted to the `executor` once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewSuccessValue>(upon queue: dispatch_queue_t, _ transform: SuccessValue throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let (progress, body) = commonBody(for: transform)
        let future = map(upon: queue, body)
        return Task(future: future, progress: progress)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// task's success value
    ///
    /// The `transform` is submitted to the `executor` once the task completes.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(_:)
    public func map<NewSuccessValue>(transform: SuccessValue throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        let (progress, body) = commonBody(for: transform)
        let future = map(body)
        return Task(future: future, progress: progress)
    }
}
