//
//  IgnoringFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A wrapped future that discards the result of the future. The wrapped
/// future is determined when the underlying future is determined, but it
/// is always determined with the empty tuple. In this way, it models the
/// empty "completion" of some event.
///
/// This is semantically identical to the following:
///
///     myFuture.map { _ in }
///
/// But may behave more efficiently.
public struct IgnoringFuture<Base: FutureType>: FutureType {
    private let base: Base
    
    /// Creates a future that ignores the result of `base`.
    public init(_ base: Base) {
        self.base = base
    }
    
    /// Call some function once the event completes.
    ///
    /// If the event is already completed, the function will be submitted to the
    /// queue immediately. An `upon` call is always execute asynchronously.
    ///
    /// - parameter queue: A dispatch queue for executing the given function on.
    public func upon(queue: dispatch_queue_t, body: () -> Void) {
        return base.upon(queue) { _ in body() }
    }
    
    /// Waits synchronously for the event to complete.
    ///
    /// If the event is already completed, the call returns immediately.
    ///
    /// - parameter time: A length of time to wait for event to complete.
    /// - returns: Nothing, if filled within the timeout, or `nil`.
    public func wait(time: Timeout) -> ()? {
        return base.wait(time).map { _ in }
    }
}
