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
    public init(_ future: Future<Result>, progress: Progress) {
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
    public convenience init(_ future: Future<Result>, uponCancel cancellation: (() -> Void)? = nil) {
        let progress = Progress.wrappingSuccess(of: future, uponCancel: cancellation)
        self.init(future, progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<Wrapped: TaskProtocol>(_ wrapped: Wrapped, progress: Progress) where Wrapped.SuccessValue == SuccessValue {
        let future = Future<Result>(wrapped)
        self.init(future, progress: progress)
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<Wrapped: FutureProtocol>(succeedsFrom wrapped: Wrapped, progress: Progress) where Wrapped.Value == SuccessValue {
        let future = Future<Result>(succeedsFrom: wrapped)
        self.init(future, progress: progress)
    }
    #else
    private let cancellation: () -> Void
    private var rawIsCancelled = false

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public init(_ future: Future<Result>, uponCancel cancellation: (() -> Void)? = nil) {
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
    public convenience init<Wrapped: TaskProtocol>(_ wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) where Wrapped.SuccessValue == SuccessValue {
        let future = Future<Result>(wrapped)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingSuccess(of: wrapped, uponCancel: cancellation)
        self.init(future, progress: progress)
        #else
        self.init(future) {
            wrapped.cancel()
            cancellation?()
        }

        if wrapped.isCancelled {
            markCancelled(using: cancellation)
        }
        #endif
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<Wrapped: FutureProtocol>(succeedsFrom wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) where Wrapped.Value == SuccessValue {
        let future = Future<Result>(succeedsFrom: wrapped)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress.wrappingCompletion(of: wrapped, uponCancel: cancellation)
        self.init(future, progress: progress)
        #else
        self.init(future, uponCancel: cancellation)
        #endif
    }

    /// Creates an operation that has already completed with `value`.
    public convenience init(success value: @autoclosure() throws -> SuccessValue) {
        let future = Future<Result>(success: value)
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future, progress: .noWork())
#else
        self.init(future)
#endif
    }

    /// Creates an operation that has already failed with `error`.
    public convenience init(failure error: Error) {
        let future = Future<Result>(failure: error)
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(future, progress: .noWork())
#else
        self.init(future)
#endif
    }

    /// Creates a task having the same underlying operation as the `other` task.
    public convenience init(_ task: Task<SuccessValue>) {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(task.future, progress: task.progress)
#else
        self.init(task.future, uponCancel: task.cancellation)
        if task.isCancelled {
            markCancelled()
        }
#endif
    }
}
