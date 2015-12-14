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

    /// Check whether or not the receiver is filled.
    internal var isFilled: Bool {
        return wait(.Now) != nil
    }
}

public extension FutureType {
    /// Begins another asynchronous operation with the deferred value once it
    /// becomes determined.
    ///
    /// `flatMap` is similar to `map`, but `transform` returns a `Deferred`
    /// instead of an immediate value. Use `flatMap` when you want this future
    /// to feed into another asynchronous operation. You might hear this
    /// referred to as "chaining" or "binding".
    ///
    /// - parameter queue: Optional dispatch queue for starting the new
    ///   operation from. Defaults to a global queue matching the current QoS.
    /// - parameter transform: Start a new operation using the deferred value.
    /// - returns: The new deferred value returned by the `transform`.
    /// - seealso: Deferred
    func flatMap<NewFuture: FutureType>(upon queue: dispatch_queue_t = genericQueue, transform: Value -> NewFuture) -> Deferred<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        upon(queue) {
            transform($0).upon(queue) {
                d.fill($0)
            }
        }
        return d
    }

    /// Transforms the future once it becomes determined.
    ///
    /// `map` executes a transform immediately when the future's value is
    /// determined.
    ///
    /// - parameter queue: Optional dispatch queue for executing the transform
    ///   from. Defaults to a global queue matching the current QoS.
    /// - parameter transform: Create something using the deferred value.
    /// - returns: A new future that is filled once the reciever is determined.
    /// - seealso: Deferred
    func map<NewValue>(upon queue: dispatch_queue_t = genericQueue, transform: Value -> NewValue) -> Deferred<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            d.fill(transform($0))
        }
        return d
    }
}

public extension FutureType {
    /// Composes this future with another.
    ///
    /// - parameter other: Any other future.
    /// - returns: A value that becomes determined after both the reciever and
    ///   the given future become determined.
    /// - seealso: SequenceType.allFutures
    func and<OtherFuture: FutureType>(other: OtherFuture) -> AnyFuture<(Value, OtherFuture.Value)> {
        return AnyFuture(flatMap { t in other.map { u in (t, u) } })
    }
}
