//
//  ExistentialTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Foundation

#if SWIFT_PACKAGE
import Atomics
import Deferred
import Result
#elseif XCODE
import Deferred.Atomics
#endif

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
public final class Task<SuccessValue>: NSObject {
    public typealias Result = TaskResult<SuccessValue>

    fileprivate let future: Future<Result>

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    /// The progress of the task, which is updated as work is completed.
    public let progress: Progress

    /// Creates a task given a `future` and its `progress`.
    public init(future: Future<Result>, progress: Progress) {
        self.future = future
        self.progress = .taskRoot(for: progress)
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
    public convenience init<Task: FutureProtocol>(_ base: Task, progress: Progress)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        self.init(future: Future(task: base), progress: progress)
    }
    #else
    fileprivate let cancellation: (() -> Void)
    fileprivate var rawIsCancelled = UnsafeAtomicBool()

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public init(future: Future<Result>, cancellation: ((Void) -> Void)? = nil) {
        self.future = future
        self.cancellation = cancellation ?? {}
    }
    #endif

    /// Create a task that will never complete.
    public override init() {
        self.future = Future()
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.progress = .indefinite()
        #else
        self.cancellation = {}
        #endif
    }

    private typealias _Self = Task<SuccessValue>

    /// Creates a task whose `upon(_:execute:)` methods use the result of `base`.
    ///
    /// If `base` is not a `Task`, `cancellation` will be called asynchronously,
    /// but not on any specific queue. If you must do work on a specific queue,
    /// schedule work on it.
    public convenience init<Task: FutureProtocol>(_ base: Task, cancellation: ((Void) -> Void)? = nil)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        let asTask = base as? _Self
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let underlying = asTask?.progress ?? .wrapped(base, cancellation: cancellation)
        self.init(future: Future(task: base), progress: underlying)
        #else
        let underlying = asTask?.cancellation ?? cancellation
        self.init(future: Future(task: base), cancellation: underlying)
        if asTask?.isCancelled == true {
            cancel()
        }
        #endif
    }

}

extension Task: FutureProtocol {
    public typealias Value = Result

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
    /// - see: isFilled
    public func cancel() {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        progress.cancel()
#else
        markCancelled()
        DispatchQueue.any().async(execute: cancellation)
#endif
    }

#if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
    fileprivate func markCancelled() {
        _ = rawIsCancelled.testAndSet()
    }
#endif

    /// Tests whether the given task has been cancelled.
    public var isCancelled: Bool {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return progress.isCancelled
#else
        return rawIsCancelled.test()
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
        if other.isCancelled {
            markCancelled()
        }
#endif
    }
}
