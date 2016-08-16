//
//  PromiseType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

/// A promise models writing the result of some asynchronous operation.
///
/// Promises should generally only be determined, or "filled", once. This allows
/// an implementing type to clear a queue of subscribers, for instance, and
/// provides consistent sharing of the determined value.
///
/// An implementing type should discourage race conditions around filling.
/// However, certain use cases inherently race (such as cancellation), and any
/// attempts to check for programmer error should be active by default.
///
public protocol PromiseType {
    /// A type that represents the result of some asynchronous operation.
    associatedtype Value
    
    /// Create the promise in a default, unfilled state
    init()

    /// Check whether or not the receiver is filled.
    var isFilled: Bool { get }

    /// Determines the deferred value with a given result.
    ///
    /// Filling a deferred value should usually be attempted only once. An
    /// implementing type may choose to enforce this.
    ///
    /// - parameter value: A resolved value for the instance.
    /// - returns: Whether the promise was fulfilled with `value`.
    @discardableResult
    func fill(_ value: Value) -> Bool
}

extension PromiseType {
    /// Determines the deferred `value`.
    ///
    /// Filling a deferred value should usually be attempted only once. A
    /// user may choose to enforce this.
    ///
    /// * In playgrounds and unoptimized builds (the default for a "Debug"
    ///   configuration) where the deferred value is already filled, program
    ///   execution will be stopped in a debuggable state.
    ///
    /// * In optimized builds (the default for a "Release" configuration) where
    ///   the deferred value is already filled, stop program execution.
    ///
    /// * In unchecked builds, filling a deferred value that is already filled
    ///   is a serious programming error. The optimizer may assume that it is
    ///   not possible.
    @_transparent
    public func mustFill(with value: Value) {
        if !fill(value) {
            preconditionFailure("Cannot fill an already-filled \(type(of: self))")
        }
    }
}
