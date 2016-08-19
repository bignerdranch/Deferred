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
import Foundation

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
public final class Task<SuccessValue>: NSObject, NSProgressReporting {
    public typealias Result = TaskResult<SuccessValue>

    private let future: Future<Result>
    public let progress: NSProgress

    /// Creates a task given a `future` and its `progress`.
    public init(future: Future<Result>, progress: NSProgress) {
        self.future = future
        self.progress = NSProgress.extendingRootIfNeeded(for: future, progress: progress)
    }

    /// Create a task that will never complete.
    public override convenience init() {
        self.init(future: Future(), progress: NSProgress(indefinite: ()))
    }

}

extension Task: TaskType {
    /// A type that represents the result of some asynchronous operation.
    public typealias Value = Result

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

extension Task {
    /// Create a task whose `upon(_:body:)` method uses the result of `base`.
    public convenience init<Task: FutureType where Task.Value: ResultType, Task.Value.Value == SuccessValue>(_ base: Task, progress: NSProgress) {
        self.init(future: Future(task: base), progress: progress)
    }

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any particular
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init(future: Future<Result>, cancellation: ((Void) -> Void)?) {
        self.init(future: future, progress: NSProgress(future: future, cancellation: cancellation))
    }

    /// Create a task whose `upon(_:_:)` method uses the result of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any particular
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<Task: FutureType where Task.Value: ResultType, Task.Value.Value == SuccessValue>(_ base: Task, cancellation: ((Void) -> Void)?) {
        self.init(future: Future(task: base), cancellation: cancellation)
    }

    /// Create a task whose `upon(_:_:)` method uses the result of `base`.
    public convenience init<Task: TaskType where Task.Value.Value == SuccessValue>(_ base: Task) {
        self.init(future: Future(task: base), progress: base.progress)
    }

    /// Wrap an operation that has already completed with `value`.
    public convenience init(@autoclosure value getValue: () throws -> SuccessValue) {
        self.init(future: Future(value: TaskResult(with: getValue)), progress: NSProgress(noWork: ()))
    }

    /// Wrap an operation that has already failed with `error`.
    public convenience init(error: ErrorType) {
        self.init(future: Future(value: TaskResult(error: error)), progress: NSProgress(noWork: ()))
    }

    /// Create a task having the same underlying operation as the `other` task.
    public convenience init(_ other: Task<SuccessValue>) {
        self.init(future: other.future, progress: other.progress)
    }
}
