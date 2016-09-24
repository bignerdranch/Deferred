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

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import class Foundation.Progress
import protocol Foundation.ProgressReporting

public final class Task<SuccessValue>: NSObject, ProgressReporting {
    public typealias Result = TaskResult<SuccessValue>

    fileprivate let future: Future<Result>
    public let progress: Progress

    /// Creates a task given a `future` and its `progress`.
    public init(future: Future<Result>, progress: Progress) {
        self.future = future
        self.progress = .taskRoot(for: progress)
    }

    /// Create a task that will never complete.
    public override init() {
        self.future = Future()
        self.progress = .indefinite()
    }

    /// Creates a task whose `upon(_:execute:)` methods use the result of `base`.
    public convenience init<Task: FutureProtocol>(_ base: Task, progress: Progress)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        self.init(future: Future(task: base), progress: progress)
    }

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public convenience init(future base: Future<Result>, cancellation: ((Void) -> Void)? = nil) {
        let progress = Progress.wrapped(base, cancellation: cancellation)
        self.init(future: base, progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use the result of `base`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public convenience init<Task: FutureProtocol>(_ base: Task, cancellation: ((Void) -> Void)? = nil)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        let progress = Progress.wrapped(base, cancellation: cancellation)
        self.init(future: Future(task: base), progress: progress)
    }
}
#else
public final class Task<SuccessValue> {
    public typealias Result = TaskResult<SuccessValue>

    fileprivate let future: Future<Result>
    public let cancellation: (() -> Void)

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public init(future: Future<Result>, cancellation: ((Void) -> Void)? = nil) {
        self.future = future
        self.cancellation = cancellation ?? {}
    }

    /// Create a task that will never complete.
    public init() {
        self.future = Future()
        self.cancellation = {}
    }

    private typealias _Self = Task<SuccessValue>

    /// Creates a task whose `upon(_:execute:)` methods use the result of `base`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public convenience init<Task: FutureProtocol>(_ base: Task, cancellation: ((Void) -> Void)? = nil)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        self.init(future: Future(task: base), cancellation: (base as? _Self)?.cancellation ?? cancellation)
    }
}
#endif

extension Task: FutureProtocol {
    public typealias Value = Result
    public typealias PreferredExecutor = Future<Result>.PreferredExecutor

    public func upon(_ queue: PreferredExecutor, execute body: @escaping(Result) -> ()) {
        future.upon(queue, execute: body)
    }

    public func upon(_ executor: Executor, execute body: @escaping(Result) -> ()) {
        future.upon(executor, execute: body)
    }

    public func wait(until timeout: DispatchTime) -> Result? {
        return future.wait(until: timeout)
    }
}

extension Task {
    /// Attempt to cancel the underlying operation.
    ///
    /// An implementation should be a "best effort". There are several
    /// situations in which cancellation may not happen:
    /// * The operation has already completed.
    /// * The operation has entered an uncancelable state.
    /// * The underlying task is not cancellable.
    ///
    /// - seealso: isFilled
    public func cancel() {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        progress.cancel()
#else
        DispatchQueue.any().async(execute: cancellation)
#endif
    }
}

extension Task {
    /// Creates an operation that has already completed with `value`.
    public convenience init(success value: @autoclosure() throws -> SuccessValue) {
        let future = Future<Result>(value: TaskResult(from: value))
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future: future, progress: .noWork())
#else
        self.init(future: future, cancellation: nil)
#endif
    }

    /// Creates an operation that has already failed with `error`.
    public convenience init(failure error: Error) {
        let future = Future<Result>(value: TaskResult(failure: error))
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future: future, progress: .noWork())
#else
        self.init(future: future, cancellation: nil)
#endif
    }

    /// Creates a task having the same underlying operation as the `other` task.
    public convenience init(_ other: Task<SuccessValue>) {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future: other.future, progress: other.progress)
#else
        self.init(future: other.future, cancellation: other.cancellation)
#endif
    }
}
