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
    func submit(body: () -> Void)

    /// If the executor is a higher-level wrapper around a dispatch queue,
    /// may be used instead of `submit(_:)` for more efficient execution.
    var underlyingQueue: dispatch_queue_t? { get }

}

extension ExecutorType {

    /// By default, `nil`; the executor's `submit(_:)` is used instead.
    public var underlyingQueue: dispatch_queue_t? {
        return nil
    }
    
}

// A `ExecutorType` wrapper for a `dispatch_queue_t`.
//
// In Swift 2.2, dispatch queues are protocol objects, and cannot be made to
// conform to other protocols. If this changes in the future, and
// `dispatch_queue_t` can be made to conform to `ExecutorType` directly, the
// overloads referenced above can be removed.
struct QueueExecutor: ExecutorType {

    private let queue: dispatch_queue_t
    init(_ queue: dispatch_queue_t) {
        self.queue = queue
    }

    func submit(body: () -> Void) {
        dispatch_async(queue, body)
    }

    var underlyingQueue: dispatch_queue_t? {
        return queue
    }

}

/// An operation queue manages a number of operation objects, making high
/// level features like cancellation and dependencies simple.
///
/// As an `ExecutorType`, `upon` closures are enqueued as non-cancellable
/// operations. This is ideal for regulating the call relative to other
/// operations in the queue.
extension NSOperationQueue: ExecutorType {

    /// Wraps the `body` closure in an operation and enqueues it.
    public func submit(body: () -> Void) {
        addOperationWithBlock(body)
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
    public func submit(body: () -> Void) {
        CFRunLoopPerformBlock(self, kCFRunLoopDefaultMode, body)
        CFRunLoopWakeUp(self)
    }

}

/// A run loop processes events on a thread, and is a fundamental construct in
/// Cocoa applications.
///
/// As an `ExecutorType`, submitted functions are invoked on the next iteration
/// of the run loop.
extension NSRunLoop: ExecutorType {

    /// Enqueues the `body` closure to be executed as the runloop cycles
    /// in the default mode.
    ///
    /// - seealso: NSDefaultRunLoopMode
    public func submit(body: () -> Void) {
        getCFRunLoop().submit(body)
    }

}

