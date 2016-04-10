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

/// A `ExecutorType` wrapper for a `dispatch_queue_t`.
///
/// In Swift 2.2, dispatch queues are protocol objects, and cannot be made to
/// conform to other protocols.
///
/// Throughout Deferred, `upon` methods or parameters are overloaded for
/// `dispatch_queue_t` to automatically create and use a `QueueExecutor`.
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

extension NSOperationQueue: ExecutorType {

    /// Wraps the `body` closure in an operation and enqueues it.
    public func submit(body: () -> Void) {
        addOperationWithBlock(body)
    }

}

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

extension NSRunLoop: ExecutorType {

    /// Enqueues the `body` closure to be executed as the runloop cycles
    /// in the default mode.
    ///
    /// - seealso: NSDefaultRunLoopMode
    public func submit(body: () -> Void) {
        getCFRunLoop().submit(body)
    }

}

