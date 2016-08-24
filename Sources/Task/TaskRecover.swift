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
import Dispatch

private func commonMapFailure<OldResult: ResultType>(body: ErrorType throws -> OldResult.Value) -> (OldResult) -> TaskResult<OldResult.Value> {
    return { oldResult in
        TaskResult {
            try oldResult.withValues(ifSuccess: { $0 }, ifFailure: { try body($0) })
        }
    }
}

extension TaskType {
    private typealias SuccessValue = Value.Value

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// failed task's error.
    ///
    /// `recover` submits the `transform` to the `executor` once the task fails.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func recover(upon executor: ExecutorType, _ body: ErrorType throws -> SuccessValue) -> Task<SuccessValue> {
        let future = map(upon: executor, commonMapFailure(body))
        return .init(future, cancellation: cancel)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// failed task's error.
    ///
    /// `recover` executes the `transform` asynchronously once the task fails.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(upon:_:)
    public func recover(upon queue: dispatch_queue_t, _ body: ErrorType throws -> SuccessValue) -> Task<SuccessValue> {
        let future = map(upon: queue, commonMapFailure(body))
        return .init(future, cancellation: cancel)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// failed task's error.
    ///
    /// `recover` executes the `transform` in the background once the task fails.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: FutureType.map(_:)
    public func recover(body: ErrorType throws -> SuccessValue) -> Task<SuccessValue> {
        let future = map(commonMapFailure(body))
        return .init(future, cancellation: cancel)
    }
}
