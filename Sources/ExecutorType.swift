//
//  ExecutorType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/29/16.
//  Copyright © 2014-2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

/// An executor calls closures submitted to it in first-in, first-out order,
/// typically on some other thread. An executor may also be used to model locks
/// or atomicity.
///
/// Throughout the Deferred module, `upon` methods (or parameters to methods
/// built around `upon`, such as `map`) are overloaded to take an `ExecutorType`
/// as well as the standard `dispatch_queue_t`.
///
/// A custom executor is a customization point into the asynchronous semantics
/// of a future, and may be important for ensuring the thread safety of an
/// `upon` closure.
///
/// For instance, the concurrency model of Apple's Core Data framework requires
/// that objects be accessed on other threads with the `performBlock(_:)` method
/// of a managed object context. We may want to connect that to Deferred:
///
///     extension NSManagedObjectContext: ExecutorType {
///
///          func submit(body: () -> Void) {
///              performBlock(body)
///          }
///
///     }
///
/// And use it like you would a dispatch queue, with `upon`:
///
///     let context: NSManagedObjectContext = ...
///     let personJSON: Future<JSON> = ...
///     let person: Future<Person> = personJSON.map(upon: context) { JSON in
///         Person(JSON: JSON, inContext: context)
///     }
///
public protocol ExecutorType {

    /// Execute the `body` closure.
    func submit(_ body: @escaping() -> Void)

    /// Execute the `workItem`.
    func submit(_ workItem: DispatchWorkItem)

    /// If the executor is a higher-level wrapper around a dispatch queue,
    /// may be used instead of `submit(_:)` for more efficient execution.
    var underlyingQueue: DispatchQueue? { get }

}

public typealias DefaultExecutor = DispatchQueue

extension ExecutorType {

    /// By default, executes the contents of the work item as a closure.
    public func submit(_ workItem: DispatchWorkItem) {
        submit(workItem.perform)
    }

    /// By default, `nil`; the executor's `submit(_:)` is always used.
    public var underlyingQueue: DispatchQueue? {
        return nil
    }
    
}

/// Dispatch queues invoke function bodies submitted to them serially in FIFO
/// order. A queue will only invoke one-at-a-time, but independent queues may
/// each invoke concurrently with respect to each other.
extension DispatchQueue: ExecutorType {

    /// Submits a function `body` for asynchronous execution.
    public func submit(_ body: @escaping() -> Void) {
        async(execute: body)
    }

    /// Submits a cancellable `workItem` for asynchronous execution.
    public func submit(_ workItem: DispatchWorkItem) {
        async(execute: workItem)
    }

    /// Returns `self`.
    public var underlyingQueue: DispatchQueue? {
        return self
    }

}

@available(*, unavailable, message: "Use DispatchQueue directly.")
struct QueueExecutor {

    init(_ queue: DispatchQueue) {
        fatalError("Unavailable type cannot be created.")
    }
    
}

/// An operation queue manages a number of operation objects, making high
/// level features like cancellation and dependencies simple.
///
/// As an `ExecutorType`, `upon` closures are enqueued as non-cancellable
/// operations. This is ideal for regulating the call relative to other
/// operations in the queue.
extension OperationQueue: ExecutorType {

    /// Wraps the `body` closure in an operation and enqueues it.
    public func submit(_ body: @escaping() -> Void) {
        addOperation(body)
    }

}

/// A run loop processes events on a thread, and is a fundamental construct in
/// Cocoa applications.
///
/// As an `ExecutorType`, submitted functions are invoked on the next iteration
/// of the run loop.
extension CFRunLoop: ExecutorType {

    /// Enqueues the `body` closure to be executed as the runloop cycles
    /// in the default mode.
    ///
    /// - seealso: kCFRunLoopDefaultMode
    public func submit(_ body: @escaping() -> Void) {
        CFRunLoopPerformBlock(self, CFRunLoopMode.defaultMode.rawValue, body)
        CFRunLoopWakeUp(self)
    }

}

/// A run loop processes events on a thread, and is a fundamental construct in
/// Cocoa applications.
///
/// As an `ExecutorType`, submitted functions are invoked on the next iteration
/// of the run loop.
extension RunLoop: ExecutorType {

    /// Enqueues the `body` closure to be executed as the runloop cycles
    /// in the default mode.
    ///
    /// - seealso: NSDefaultRunLoopMode
    public func submit(_ body: @escaping() -> Void) {
        getCFRunLoop().submit(body)
    }

}

