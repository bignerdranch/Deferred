//
//  ExistentialTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/16.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
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

/// A type for managing some work that may either succeed or fail at some point
/// in the future, including interacting with the end result of the work.
///
/// Tasks work exactly like futures but, because they operate on types that
/// have one or more exclusive states to describe a success or failure, have
/// patterns for dealing with just the successful value, the failing error,
/// chaining dependent operations together, recovering from errors, and so on.
///
/// Returning a `Task` from your API encapsulates the entire lifecycle of
/// asynchronous work, regardless of it being managed by `OperationQueue`,
/// or `DispatchQueue`, or `URLSession`. Consumers of your `Task` object might
/// interact with the task by cancelling, pausing, or resuming it.
///
/// Creating a Task
/// ===============
///
/// Like `Future`, a task will forward operations involving the result of the
/// work being performed to some underlying type, hiding the implementation
/// details of your asynchronous API.
///
///     let promise = Task<Int>.Promise()
///     DispatchQueue.any().asyncAfter(deadline: .now() + 3) {
///         if Bool.random() {
///             promise.succeed(with: 4) // chosen by fair dice roll.
///                                      // guaranteed to be random.
///         } else {
///             promise.fail(with: Error.reallyBad)
///         }
///     }
///     return Task(promise)
///
/// Tasks Represent Workflows
/// =========================
///
/// You can design an API to use `Task` even the result is known immediately.
/// This allows you to evolve your code over time without changing callers of
/// the code.
///
///     let alreadySucceeded = Task(success: "13 miles away")
///     let alreadyFailed = Task(failure: Error.couldNotFetchLocation)
///
/// Consider a method that checks the validity of parameters to a web
/// service before fetching from it:
///
///     func fetchFriends(for user: User) throws -> Future<[Friend]?> {
///         guard !user.id.isEmpty else {
///             throw Error.invalidParameters
///         }
///
///         ...
///     }
///
/// Consuming this asynchronous value must be done in multiple paths:
///
///     do {
///         let futureFriends = try fetchFriends(for: currentUser)
///         futureFriends.upon(managedObjectContext) { (friends) in
///             if let friends = friends {
///                 do {
///                      try import(friends)
///                 catch {
///                      // handle an error
///                 }
///             } else {
///                 // handle an error
///             }
///         }
///     } catch {
///         // handle an error
///     }
///
/// Embracing `Task` as the common currency type between layers of code in
/// your application can consolidate these multiple branches of checking.
///
///     func fetchFriends(for user: User) -> Task<[Friend]> {
///         guard !user.id.isEmpty else {
///             return Task(failure: Error.invalidParameters)
///         }
///
///         ...
///     }
///
///     fetchFriends(for: currentUser)
///         .map(upon: managedObjectContext, transform: import)
///         .uponSuccess(on: .main) { _ in /* handle success */ }
///         .uponFailure(on: .main) { _ in /* handle failure */ }
///
/// Tasks Can Be Cancelled
/// ======================
///
/// When creating a task from a future or promise, an optional `cancellation`
/// handler can be provided. Inside this method body, you can cancel ongoing
/// work, such as a network connection or image processing.
///
/// When the underlying work can be interrupted, cancelling a `Task` will
/// typically lead to the operation completing with an error, such as
/// `CocoaError.userCancelled`.
///
///     let promise = Task<UIImage>.Promise()
///     let operation = makeImageProcessingOperation(for: data)
///     operation.completionBlock = { [unowned operation] in
///         promise.fill(with: operation.result!)
///     }
///     operationQueue.add(operation)
///     return Task(promise, uponCancel: operation.cancel)
///
/// Cancellation may be invoked in any threading context. If work associated
/// with cancellation must be done on a specific queue, dispatch to that queue
/// from within the cancellation handler.
///
/// Tasks Can Report Progress
/// =========================
///
/// On macOS, iOS, watchOS, and tvOS, where apps are expected to react to
/// current conditions, `Task` will automatically maintain instances of the
/// `Progress` object. These objects can be used to drive UI controls displaying
/// that progress, as well as interactive controls like buttons to cancel,
/// pause, or resume the work.
///
/// In the simplest cases, using `Task` and methods like `map` and `andThen`
/// give some insight into the work your application is doing and improve the
/// user experience. Consider:
///
///     let task = downloadImage(for: url)
///         .map(upon: .any(), transform: decompressImage)
///         .map(upon: .any(), start: applyFiltersToImage)
///         .map(upon: .any(), start: writeImageToCache)
///
/// `task.progress` will have four work units, each of which will complete after
/// the work assiociated with the initial task, `map`, `andThen`, and `map`,
/// yielding progress updates of 25%, 50%, 75%, and 100% respectively.
///
/// If you have a better source of data for progress, like those provided on
/// `URLSessionTask` or `UIDocument`, those can also be incorporated into
/// `Task` during creation. These `Task`s are weighted more than surrounding
/// calls to `map` or `andThen`. For instance, you can modify `downloadImage`
/// above to include another source of progress:
///
///     func downloadImage(for url: URL) -> Task<Data> {
///         let promise = Task<Data>.Promise()
///         let urlSessionTask = urlSession.dataTask(with: url) {
///            promise.fill(with: ...)
///         }
///         urlSessionTask.resume()
///         return Task(promise, progress: urlSessionTask.progress)
///     }
///
/// `downloadImage` will account for up to 90% of the returned progress. That
/// 90% "slice" will fill in as chunks of data get loaded from the network.
///
/// You may also create your own `Progress` instances to be given to `Task`.
/// Progress objects use any context you desire, like byte counts or fractions,
/// and will also be weighted higher by `Task`. If `applyFiltersToImage` above
/// applies 5 user-selected filters, you might create a custom progress and
/// update it when each of the filters is complete:
///
///      func applyFiltersToImage(_ image: UIImage) -> UIImage {
///          var image = image
///          let progress = Progress(totalUnitCount: filters.count)
///          for (n, filter) in filters.enumerated() {
///              image = filter.apply(to: image)
///              progress.completedUnitCount = n
///          }
///          return image
///      }
///
/// `downloadImage` and `applyFiltersToImage` will each take up to 45% of the
/// returned progress.
///
/// - seealso: `TaskProtocol`
/// - seealso: `Future`
public final class Task<Success> {
    @available(*, unavailable, renamed: "Success", message: "Renamed 'Success' to better align with SE-0235, the Swift 5 Result type.")
    public typealias SuccessValue = Success

    /// A type that represents either a wrapped value or an error, representing the
    /// possible return values of a throwing function.
    public enum Result {
        /// Any error.
        public typealias Failure = Error
        /// The success value, stored as `Value`.
        case success(Success)
        /// The failure value, stored as any error.
        case failure(Failure)
    }

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
        self.progress = TaskChain(startingWith: future, using: progress).effectiveProgress
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public init<Wrapped: TaskProtocol>(_ wrapped: Wrapped, progress: Progress) where Wrapped.Success == Success {
        self.future = Future<Result>(resultFrom: wrapped)
        self.progress = TaskChain(startingWith: wrapped, using: progress).effectiveProgress
    }
    #else
    private let cancellation: () -> Void
    private var rawIsCancelled = false
    #endif

    /// Creates a task given a `future` and an optional `cancellation`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public init(_ future: Future<Result>, uponCancel cancellation: (() -> Void)? = nil) {
        self.future = future
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.progress = TaskChain(startingWith: future, uponCancel: cancellation).effectiveProgress
        #else
        self.cancellation = cancellation ?? {}
        #endif
    }

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public init<Wrapped: TaskProtocol>(_ wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) where Wrapped.Success == Success {
        self.future = Future<Result>(resultFrom: wrapped)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.progress = TaskChain(startingWith: wrapped, uponCancel: cancellation).effectiveProgress
        #else
        self.cancellation = {
            wrapped.cancel()
            cancellation?()
        }
        #endif
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
    /// A type for communicating the result of asynchronous work.
    ///
    /// Create an instance of the task's `Promise` to be filled asynchronously.
    ///
    /// - seealso: `Task.async(upon:flags:onCancel:execute:)`
    public typealias Promise = Deferred<Result>

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    public convenience init<Wrapped: FutureProtocol>(succeedsFrom wrapped: Wrapped, progress: Progress) where Wrapped.Value == Success {
        let future = Future<Result>(succeedsFrom: wrapped)
        self.init(future, progress: progress)
    }
    #endif

    /// Creates a task whose `upon(_:execute:)` methods use those of `base`.
    ///
    /// `cancellation` will be called asynchronously, but not on any specific
    /// queue. If you must do work on a specific queue, schedule work on it.
    public convenience init<Wrapped: FutureProtocol>(succeedsFrom wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) where Wrapped.Value == Success {
        let future = Future<Result>(succeedsFrom: wrapped)
        self.init(future, uponCancel: cancellation)
    }

    /// Creates an operation that has already completed with `value`.
    public convenience init(success value: @autoclosure() throws -> Success) {
        let future = Future<Result>(success: try value())
        self.init(future)
    }

    /// Creates an operation that has already failed with `error`.
    public convenience init(failure error: Failure) {
        let future = Future<Result>(failure: error)
        self.init(future)
    }

    /// Creates a task having the same underlying operation as the `other` task.
    public convenience init(_ task: Task<Success>) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        self.init(task.future, progress: task.progress)
        #else
        self.init(task.future, uponCancel: task.cancellation)
        if task.isCancelled {
            markCancelled()
        }
        #endif
    }

    /// Create a task that will never complete.
    public static var never: Task<Success> {
        return Task(Future<Result>.never)
    }
}

extension Task {
    @available(*, unavailable, message: "Replace with 'Task.never' for clarity.")
    public convenience init() {
        fatalError("unavailable initializer cannot be called")
    }

    @available(*, unavailable, renamed: "init(_:uponCancel:)")
    public convenience init<Wrapped: TaskProtocol>(_ wrapped: Wrapped, cancellation: (() -> Void)? = nil) {
        fatalError("unavailable initializer cannot be called")
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    @available(*, unavailable, renamed: "init(_:progress:)")
    public convenience init(future: Future<Result>, progress: Progress) {
        fatalError("unavailable initializer cannot be called")
    }

    @available(*, unavailable, renamed: "init(succeedsFrom:progress:)", message: "Replace with 'init(succeedsFrom:progress:)' to disambiguate from a completed Task.")
    public convenience init<Wrapped: FutureProtocol>(success wrapped: Wrapped, progress: Progress) where Wrapped.Value == Success {
        fatalError("unavailable initializer cannot be called")
    }
    #endif

    @available(*, unavailable, renamed: "init(_:uponCancel:)")
    public convenience init(future: Future<Result>, cancellation: (() -> Void)? = nil) {
        fatalError("unavailable initializer cannot be called")
    }

    @available(*, unavailable, renamed: "init(succeedsFrom:uponCancel:)", message: "Replace with 'init(succeedsFrom:uponCancel:)' to disambiguate from a completed Task.")
    public convenience init<Wrapped: FutureProtocol>(success wrapped: Wrapped, cancellation: (() -> Void)? = nil) {
        fatalError("unavailable initializer cannot be called")
    }
}
