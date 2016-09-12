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

extension ExecutorType {

    /// By default, executes the contents of the work item as a closure.
    public func submit(_ workItem: DispatchWorkItem) {
        submit(workItem.perform)
    }

    /// By default, `nil`; the executor's `submit(_:)` is used instead.
    public var underlyingQueue: DispatchQueue? {
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

    private let queue: DispatchQueue
    init(_ queue: DispatchQueue) {
        self.queue = queue
    }

    func submit(_ body: @escaping() -> Void) {
        queue.async(execute: body)
    }

    var underlyingQueue: DispatchQueue? {
        return queue
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
    @nonobjc public func submit(_ body: @escaping() -> Void) {
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
    @nonobjc public func submit(_ body: @escaping() -> Void) {
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
    @nonobjc public func submit(_ body: @escaping() -> Void) {
        getCFRunLoop().submit(body)
    }

}

