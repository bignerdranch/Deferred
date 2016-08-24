//
//  IgnoringTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/15/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

private extension ResultType {
    func ignored() -> TaskResult<Void> {
        return withValues(ifSuccess: { _ in TaskResult.Success() }, ifFailure: TaskResult.Failure)
    }
}

public struct IgnoringTask<Base: FutureType where Base.Value: ResultType> {
    public typealias Result = TaskResult<Void>

    private let base: Base
    private let cancellation: Cancellation

    /// Creates an event given with a `base` future and an optional
    /// `cancellation`.
    private init(_ base: Base, cancellation: Cancellation) {
        self.base = base
        self.cancellation = cancellation
    }
}

extension IgnoringTask: FutureType {
    /// Call some function once the event completes.
    ///
    /// If the event is already completed, the function will be submitted to the
    /// queue immediately. An `upon` call is always execute asynchronously.
    ///
    /// - parameter queue: A dispatch queue for executing the given function on.
    public func upon(executor: ExecutorType, body: Result -> ()) {
        return base.upon(executor) { body($0.ignored()) }
    }

    /// Waits synchronously for the event to complete.
    ///
    /// If the event is already completed, the call returns immediately.
    ///
    /// - parameter time: A length of time to wait for event to complete.
    /// - returns: Nothing, if filled within the timeout, or `nil`.
    public func wait(time: Timeout) -> Result? {
        return base.wait(time).map { $0.ignored() }
    }
}

extension IgnoringTask: TaskType {
    /// Attempt to cancel the underlying operation. This is a "best effort".
    public func cancel() {
        cancellation()
    }
}

extension TaskType {
    /// Returns a task that ignores the successful completion of this task.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myTask.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: map(_:)
    public func ignored() -> IgnoringTask<Self> {
        return IgnoringTask(self, cancellation: cancel)
    }
}
