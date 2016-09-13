//
//  Future.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A future models reading a value which may become available at some point.
///
/// A `FutureProtocol` may be preferable to an architecture using completion
/// handlers; separating the mechanism for handling the completion from the call
/// that began it leads to a more readable code flow.
///
/// A future is primarily useful as a joining mechanism for asynchronous
/// operations. Though the protocol requires a synchronous accessor, its use is
/// not recommended outside of testing. `upon` is preferred for nearly all access:
///
///     myFuture.upon(.main) { value in
///       print("I now have the value: \(value)")
///     }
///
/// `FutureProtocol` makes no requirement on conforming types regarding thread-safe
/// access, though ideally all members of the future could be called from any
/// thread.
///
public protocol FutureProtocol: CustomDebugStringConvertible, CustomReflectable {
    /// A type that represents the result of some asynchronous operation.
    associatedtype Value

    /// The natural executor for use with this future, either by convention or
    /// implementation detail.
    associatedtype PreferredExecutor: Executor = DefaultExecutor

    /// Calls some `body` closure once the value is determined.
    ///
    /// By default, calls `upon(_:body:)` with an `Executor`. This method
    /// serves as sugar for types with global members such as `DispatchQueue`.
    func upon(_ executor: PreferredExecutor, execute body: @escaping(Value) -> Void)

    /// Call some `body` closure once the value is determined.
    ///
    /// If the value is determined, the closure should be submitted to the
    /// `executor` immediately.
    func upon(_ executor: Executor, execute body: @escaping(Value) -> Void)

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with
    /// the value.
    ///
    /// - parameter time: A deadline for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    func wait(until time: DispatchTime) -> Value?
}

extension FutureProtocol {
    public func upon(_ executor: PreferredExecutor, execute body: @escaping(Value) -> Void) {
        upon(executor as Executor, execute: body)
    }
}

extension FutureProtocol where PreferredExecutor == DispatchQueue {
    /// Call some `body` closure in the background once the value is determined.
    ///
    /// If the value is determined, the closure will be enqueued immediately,
    /// but this call is always asynchronous.
    public func upon(execute body: @escaping(Value) -> Void) {
        upon(.any(), execute: body)
    }
}

extension FutureProtocol {
    /// Checks for and returns a determined value.
    ///
    /// - returns: The determined value, if already filled, or `nil`.
    public func peek() -> Value? {
        return wait(until: .now())
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
        return wait(until: .distantFuture).unsafelyUnwrapped
    }

    /// Check whether or not the receiver is filled.
    var isFilled: Bool {
        return wait(until: .now()) != nil
    }
}

extension FutureProtocol {

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
