//
//  FutureType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// A generic catch-all dispatch queue for use with futures, when you just want
// to throw some work into the concurrent pile. As an alternative to the
// `QOS_CLASS_UTILITY` global queue, work dispatched onto this queue matches
// the QoS of the caller, which is generally the right behavior.
//
// The technique is described and used in Core Foundation:
// http://opensource.apple.com/source/CF/CF-1153.18/CFInternal.h
var genericQueue: dispatch_queue_t! {
    return dispatch_get_global_queue(qos_class_self(), 0)
}

/// A future models reading a value which may become available at some point.
///
/// A `FutureType` may be preferable to an architecture using completion
/// handlers; separating the mechanism for handling the completion from the call
/// that began it leads to a more readable code flow.
///
/// A future is primarily useful as a joining mechanism for asynchronous
/// operations. Though the protocol requires a synchronous accessor, its use is
/// not recommended outside of testing. `upon` is preferred for nearly all access:
///
///     myFuture.upon(dispatch_get_main_queue()) { value in
///       print("I now have the value: \(value)")
///     }
///
/// `FutureType` makes no requirement on conforming types regarding thread-safe
/// access, though ideally all members of the future could be called from any
/// thread.
///
public protocol FutureType {
    /// A type that represents the result of some asynchronous operation.
    typealias Value

    /// Call some function once the value is determined.
    ///
    /// If the value is determined, the function should be submitted to the
    /// queue immediately. An `upon` call should always execute asynchronously.
    ///
    /// - parameter queue: A dispatch queue for executing the given function on.
    /// - parameter body: A function that uses the determined value.
    func upon(queue: dispatch_queue_t, body: Value -> ())

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with the
    /// value.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    func wait(time: Timeout) -> Value?
}

public extension FutureType {
    /// Call some function in the background once the value is determined.
    ///
    /// If the value is determined, the function will be dispatched immediately.
    /// An `upon` call should always execute asynchronously.
    ///
    /// - parameter body: A function that uses the determined value.
    func upon(body: Value -> ()) {
        upon(genericQueue, body: body)
    }

    /// Call some function on the main queue once the value is determined.
    ///
    /// If the value is determined, the function will be submitted to the
    /// main queue immediately. The function should always be executed
    /// asynchronously, even if this function is called from the main queue.
    ///
    /// - parameter body: A function that uses the determined value.
    func uponMainQueue(body: Value -> ()) {
        upon(dispatch_get_main_queue(), body: body)
    }
}

public extension FutureType {
    /// Checks for and returns a determined value.
    ///
    /// - returns: The determined value, if already filled, or `nil`.
    func peek() -> Value? {
        return wait(.Now)
    }

    /// Waits for the value to become determined, then returns it.
    ///
    /// This is equivalent to unwrapping the value of calling `wait(.Forever)`,
    /// but may be more efficient.
    ///
    /// This getter will unnecessarily block execution. It might be useful for
    /// testing, but otherwise it should be strictly avoided.
    ///
    /// - returns: The determined value.
    internal var value: Value {
        return unsafeUnwrap(wait(.Forever))
    }
}
