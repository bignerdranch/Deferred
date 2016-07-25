//
//  ExistentialTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

/// A simple function type expressing the cancellation of some operation.
public typealias Cancellation = () -> Void

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
public struct Task<SuccessValue> {
    public typealias Result = TaskResult<SuccessValue>

    private let future: Future<Result>
    private let cancellation: Cancellation

    /// Creates a task given a `future` and an optional `cancellation`.
    public init(_ future: Future<Result>, cancellation: Cancellation) {
        self.future = future
        self.cancellation = cancellation
    }
}

extension Task: FutureType {
    /// Call some function once the operation completes.
    ///
    /// If the task is complete, the function will be submitted to the
    /// queue immediately. An `upon` call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue for executing the given function on.
    /// - parameter body: A function that uses the determined value.
    public func upon(executor: ExecutorType, body: Result -> ()) {
        future.upon(executor, body: body)
    }

    /// Waits synchronously for the operation to complete.
    ///
    /// If the task is complete, the call returns immediately with the value.
    ///
    /// - returns: The task's result, if filled within `timeout`, or `nil`.
    public func wait(timeout: Timeout) -> Result? {
        return future.wait(timeout)
    }
}

extension Task: TaskType {
    /// Attempt to cancel the underlying operation. This is a "best effort".
    public func cancel() {
        cancellation()
    }
}

extension Task {
    /// Create a task whose `upon(_:body:)` method uses the result of `base`.
    public init<Task: FutureType where Task.Value: ResultType, Task.Value.Value == SuccessValue>(_ base: Task, cancellation: Cancellation) {
        self.init(Future(task: base), cancellation: cancellation)
    }

    /// Create a task whose `upon(_:body:)` method uses the result of `base`.
    public init<Task: TaskType where Task.Value.Value == SuccessValue>(_ base: Task) {
        self.init(Future(task: base), cancellation: base.cancel)
    }

    /// Wrap an operation that has already completed with `value`.
    public init(@autoclosure value getValue: () throws -> SuccessValue) {
        self.init(Future(value: TaskResult(with: getValue)), cancellation: {})
    }

    /// Wrap an operation that has already failed with `error`.
    public init(error: ErrorType) {
        self.init(Future(value: TaskResult(error: error)), cancellation: {})
    }

    /// Create a task that will never complete.
    public init() {
        self.init(Future(), cancellation: {})
    }

    /// Create a task having the same underlying operation as the `other` task.
    public init(_ other: Task<SuccessValue>) {
        self.init(other.future, cancellation: other.cancellation)
    }
}
