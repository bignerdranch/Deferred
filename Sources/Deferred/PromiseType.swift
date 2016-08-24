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
    func fill(value: Value) -> Bool
}

extension PromiseType {
    /// Determines the deferred value with a given result.
    ///
    /// Filling a deferred value should usually be attempted only once. An
    /// implementing type may choose to enforce this by default. If an
    /// implementing type requires multiple potential fillers to race, the
    /// precondition may be disabled.
    ///
    /// * In playgrounds and unoptimized builds (the default for a "Debug"
    ///   configuration), program execution should be stopped at the caller in
    ///   a debuggable state.
    ///
    /// * In -O builds (the default for a "Release" configuration), program
    ///   execution should stop.
    ///
    /// * In -Ounchecked builds, the programming error should be assumed to not
    ///   exist.
    ///
    /// - parameter value: A resolved value for the instance.
    /// - parameter assertIfFilled: If `false`, race checking is disabled.
    public func fill(value: Value, assertIfFilled: Bool, file: StaticString = #file, line: UInt = #line) {
        if !fill(value) && assertIfFilled {
            assertionFailure("Cannot fill an already-filled \(self.dynamicType)", file: file, line: line)
        }
    }
}
