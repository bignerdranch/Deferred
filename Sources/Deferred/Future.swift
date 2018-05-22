//
//  Future.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
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

    /// Call some `body` closure once the value is determined.
    ///
    /// If the value is determined, the closure should be submitted to the
    /// `executor` immediately.
    func upon(_ executor: Executor, execute body: @escaping(Value) -> Void)

    /// Checks for and returns a determined value.
    ///
    /// An implementation should use a "best effort" to return this value and
    /// not unnecessarily block in order to to return.
    ///
    /// - returns: The determined value, if already filled, or `nil`.
    func peek() -> Value?

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with
    /// the value.
    ///
    /// - parameter time: A deadline for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    func wait(until time: DispatchTime) -> Value?
}

// MARK: - Default implementations

extension FutureProtocol {
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        var ret = ""
        ret.append(contentsOf: "\(Self.self)".prefix(while: { $0 != "<" }))
        ret.append("(")
        switch peek() {
        case _? where Value.self == Void.self:
            ret.append("filled")
        case let value?:
            debugPrint(value, terminator: "", to: &ret)
        case nil:
            ret.append("not filled")
        }
        ret.append(")")
        return ret
    }

    /// Return the `Mirror` for `self`.
    public var customMirror: Mirror {
        let child: Mirror.Child
        switch peek() {
        case let value? where Value.self != Void.self:
            child = (label: "value", value: value)
        case let other:
            child = (label: "isFilled", value: other != nil)
        }
        return Mirror(self, children: CollectionOfOne(child), displayStyle: .optional, ancestorRepresentation: .suppressed)
    }
}
