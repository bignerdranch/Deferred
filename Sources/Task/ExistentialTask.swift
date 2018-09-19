//
//  ExistentialTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/16.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Foundation
#if SWIFT_PACKAGE
import Atomics
import Deferred
#elseif COCOAPODS
import Atomics
#elseif XCODE && !FORCE_PLAYGROUND_COMPATIBILITY
import Deferred.Atomics
#endif

/// A wrapper over any task.
///
/// Forwards operations to an arbitrary underlying future having the same result
/// type, optionally combined with some `cancellation`.
public final class Task<SuccessValue>: NSObject {
    /// A type for returning and propagating recoverable errors.
    public typealias Result = TaskResult<SuccessValue>

    /// A type for communicating the result of asynchronous work.
    ///
    /// Create an instance of the task's `Promise` to be filled asynchronously.
    ///
    /// - seealso: `Task.async(upon:flags:onCancel:execute:)`
    public typealias Promise = Deferred<Result>

    private let future: Future<Result>

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

    private init(never: ()) {
        self.future = .never
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
    public convenience init<OtherTask: TaskProtocol>(_ base: OtherTask, progress: Progress) where OtherTask.SuccessValue == SuccessValue {
        let future = Future<Result>(task: base)
        self.init(future: future, progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<OtherFuture: FutureProtocol>(success base: OtherFuture, progress: Progress) where OtherFuture.Value == SuccessValue {
        let future = Future<Result>(success: base)
        self.init(future: future, progress: progress)
    }
    #else
    private let cancellation: () -> Void
    private var rawIsCancelled = false

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public init(future: Future<Result>, cancellation: (() -> Void)? = nil) {
        self.future = future
        self.cancellation = cancellation ?? {}
    }

    private init(never: ()) {
        self.future = .never
        self.cancellation = {}
    }
    #endif

    /// Create a task that will never complete.
    public static var never: Task<SuccessValue> {
        return Task(never: ())
    }
}

extension Task: TaskProtocol {
    public func upon(_ executor: Executor, execute body: @escaping(Result) -> Void) {
        future.upon(executor, execute: body)
    }

    public func peek() -> Result? {
        return future.peek()
    }

    public func wait(until timeout: DispatchTime) -> Result? {
        return future.wait(until: timeout)
    }

    public var isCancelled: Bool {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return progress.isCancelled
        #else
        return bnr_atomic_load(&rawIsCancelled, .relaxed)
        #endif
    }

    #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
    private func markCancelled(using cancellation: (() -> Void)? = nil) {
        bnr_atomic_store(&rawIsCancelled, true, .relaxed)

        if let cancellation = cancellation {
            DispatchQueue.any().async(execute: cancellation)
        }
    }
    #endif

    public func cancel() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        progress.cancel()
        #else
        markCancelled(using: cancellation)
        #endif
    }
}

extension Task {
    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<OtherTask: TaskProtocol>(_ base: OtherTask, cancellation: (() -> Void)? = nil) where OtherTask.SuccessValue == SuccessValue {
        let future = Future<Result>(task: base)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingSuccess(of: base, cancellation: cancellation)
        self.init(future: future, progress: progress)
        #else
        self.init(future: future) {
            base.cancel()
            cancellation?()
        }

        if base.isCancelled {
            markCancelled(using: cancellation)
        }
        #endif
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<OtherFuture: FutureProtocol>(success base: OtherFuture, cancellation: (() -> Void)? = nil) where OtherFuture.Value == SuccessValue {
        let future = Future<Result>(success: base)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingCompletion(of: base, cancellation: cancellation)
        self.init(future: future, progress: progress)
        #else
        self.init(future: future)
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
