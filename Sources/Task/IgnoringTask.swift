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
import Foundation

private extension ResultType {
    func ignored() -> TaskResult<Void> {
        return withValues(ifSuccess: { _ in TaskResult.Success() }, ifFailure: TaskResult.Failure)
    }
}

public struct IgnoringTask<Base: FutureType where Base.Value: ResultType> {
    public typealias Result = TaskResult<Void>

    private let base: Base
    public let progress: NSProgress

    /// Creates an event given with a `base` future and its `progress`.
    private init(_ base: Base, progress: NSProgress) {
        self.base = base
        self.progress = progress
    }
}

extension IgnoringTask: TaskType {
    /// A type that represents the result of some asynchronous event.
    public typealias Value = Result

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
        return IgnoringTask(self, progress: progress)
    }
}
