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
#elseif COCOAPODS
import Atomics
#elseif XCODE
import Deferred.Atomics
#endif

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
public final class Task<SuccessValue>: NSObject {

    #if swift(>=3.1)
    /// An enum for returning and propagating recoverable errors.
    public enum Result {
        /// Contains the success value
        case success(SuccessValue)
        /// Contains the error value
        case failure(Error)
    }
    #else
    public typealias Result = TaskResult<SuccessValue>
    #endif

    fileprivate let future: Future<Result>

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    /// The progress of the task, which may be updated as work is completed.
    ///
    /// If the task does not report progress, this progress is indeterminate,
    /// and becomes determinate and completed when the task is finished.
    @objc dynamic
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

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init(future base: Future<Result>, cancellation: (() -> Void)? = nil) {
        let progress = Progress.wrappingSuccess(of: base, cancellation: cancellation)
        self.init(future: base, progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<Task: FutureProtocol>(_ base: Task, progress: Progress)
        where Task.Value: Either, Task.Value.Left == Error, Task.Value.Right == SuccessValue {
        self.init(future: Future(task: base), progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<OtherFuture: FutureProtocol>(success base: OtherFuture, progress: Progress)
        where OtherFuture.Value == SuccessValue {
        self.init(future: Future(success: base), progress: progress)
    }
    #else
    fileprivate let cancellation: (() -> Void)
    fileprivate var rawIsCancelled = UnsafeAtomicBool()

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public init(future: Future<Result>, cancellation: (() -> Void)? = nil) {
        self.future = future
        self.cancellation = cancellation ?? {}
    }

    /// Create a task that will never complete.
    public override init() {
        self.future = Future()
        self.cancellation = {}
    }
    #endif
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
        _ = bnr_atomic_flag_test_and_set(&rawIsCancelled)
    }
#endif

    /// Tests whether the given task has been cancelled.
    public var isCancelled: Bool {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return progress.isCancelled
#else
        return bnr_atomic_flag_test(&rawIsCancelled)
#endif
    }
}

extension Task {
    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<OtherFuture: FutureProtocol>(_ base: OtherFuture, cancellation: (() -> Void)? = nil)
        where OtherFuture.Value: Either, OtherFuture.Value.Left == Error, OtherFuture.Value.Right == SuccessValue {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingSuccess(of: base, cancellation: cancellation)
        self.init(future: Future(task: base), progress: progress)
#else
        let asTask = (base as? Task<SuccessValue>)

        self.init(future: Future(task: base)) { [oldCancellation = asTask?.cancellation] in
            oldCancellation?()
            cancellation?()
        }

        if asTask?.isCancelled == true {
            cancel()
        }
#endif
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<OtherFuture: FutureProtocol>(success base: OtherFuture, cancellation: (() -> Void)? = nil)
        where OtherFuture.Value == SuccessValue {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingCompletion(of: base, cancellation: cancellation)
        self.init(future: Future<Value>(success: base), progress: progress)
#else
        self.init(future: Future<Value>(success: base))
#endif
    }

    /// Creates an operation that has already completed with `value`.
    public convenience init(success value: @autoclosure() throws -> SuccessValue) {
        let future = Future<Result>(value: Result(from: value))
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future: future, progress: .noWork())
#else
        self.init(future: future, cancellation: nil)
#endif
    }

    /// Creates an operation that has already failed with `error`.
    public convenience init(failure error: Error) {
        let future = Future<Result>(value: Result(failure: error))
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
