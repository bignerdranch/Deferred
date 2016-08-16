//
//  FutureType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

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
public protocol FutureType: CustomDebugStringConvertible, CustomReflectable {
    /// A type that represents the result of some asynchronous operation.
    associatedtype Value

    /// The natural executor for use with this future, either by convention or
    /// implementation detail.
    associatedtype PreferredExecutor: ExecutorType = DefaultExecutor

    /// Call some `body` closure once the value is determined.
    ///
    /// If the value is determined, the closure should be submitted to the
    /// `executor` immediately.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined value.
    func upon(_ executor: ExecutorType, body: @escaping(Value) -> Void)

    /// Calls some `body` closure once the value is determined.
    ///
    /// By default, calls `upon(_:body:)` with an `ExecutorType`. This method
    /// serves as sugar for types with global members such as `DispatchQueue`.
    func upon(_ executor: PreferredExecutor, body: @escaping(Value) -> Void)

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with
    /// the value.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    func wait(_ time: Timeout) -> Value?
}

extension FutureType {
    /// A generic catch-all dispatch queue for use with futures, when you just
    /// want to throw some work into the concurrent pile. As an alternative to
    /// the `.utility` QoS global queue, work dispatched onto this queue
    /// on platforms with QoS will match the QoS of the caller, which is
    /// generally the right behavior for data flow.
    public static var genericQueue: DispatchQueue {
        return .global(qos: .current)
    }
}

extension FutureType {
    /// Calls some `body` closure once the value is determined.
    ///
    /// By default, calls `upon(_:body:)` with an `ExecutorType`. This method
    /// serves as sugar for types with global members such as `DispatchQueue`.
    public func upon(_ preferred: PreferredExecutor, body: @escaping(Value) -> Void) {
        upon(preferred as ExecutorType, body: body)
    }

    /// Call some `body` closure in the background once the value is determined.
    ///
    /// If the value is determined, the closure will be enqueued immediately,
    /// but this call is always asynchronous.
    public func upon(_ body: @escaping(Value) -> Void) {
        upon(Self.genericQueue, body: body)
    }
}

extension FutureType where PreferredExecutor == DispatchQueue {
    /// Call some `body` closure on the main queue once the value is determined.
    ///
    /// If the value is determined, the closure will be submitted to the
    /// main queue. It will always execute asynchronously, even if this call is
    /// made from the main queue.
    ///
    /// - parameter body: A closure that uses the determined value.
    @available(*, unavailable, message: "Use upon(.main) directly.")
    public func uponMainQueue(_ body: @escaping(Value) -> Void) {
        upon(.main, body: body)
    }
}

extension FutureType {
    /// Checks for and returns a determined value.
    ///
    /// - returns: The determined value, if already filled, or `nil`.
    public func peek() -> Value? {
        return wait(.now)
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
    var value: Value {
        return wait(.forever).unsafelyUnwrapped
    }

    /// Check whether or not the receiver is filled.
    var isFilled: Bool {
        return wait(.now) != nil
    }
}

extension FutureType {

    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        var ret = "\(Self.self)"
        if Value.self == Void.self && isFilled {
            ret += " (filled)"
        } else if let value = peek() {
            ret += "(\(String(reflecting: value)))"
        } else {
            ret += " (not filled)"
        }
        return ret
    }

    /// Return the `Mirror` for `self`.
    public var customMirror: Mirror {
        if Value.self != Void.self, let value = peek() {
            return Mirror(self, children: [ "value": value ], displayStyle: .optional)
        } else {
            return Mirror(self, children: [ "isFilled": isFilled ], displayStyle: .tuple)
        }
    }

}
