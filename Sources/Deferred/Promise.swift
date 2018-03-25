//
//  Promise.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

/// A promise models writing the result of some asynchronous operation.
///
/// Promises should generally only be determined, or "filled", once. This allows
/// an implementing type to clear a queue of subscribers, for instance, and
/// provides consistent sharing of the determined value.
///
/// An implementing type should discourage race conditions around filling.
/// However, certain use cases inherently race (such as cancellation). Any
/// attempts to check for programmer error should be active by default.
public protocol PromiseProtocol {
    /// A type that represents the result of some asynchronous operation.
    associatedtype Value

    /// Creates an instance in a default, unfilled state.
    init()

    /// Check whether or not the receiver is filled.
    var isFilled: Bool { get }

    /// Determines the promise with `value`.
    ///
    /// Filling a deferred value should usually be attempted only once.
    ///
    /// - returns: Whether the promise was fulfilled with `value`.
    @discardableResult
    func fill(with value: Value) -> Bool
}

extension PromiseProtocol {
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
    public func mustFill(with value: Value, file: StaticString = #file, line: UInt = #line) {
        if !fill(with: value) {
            preconditionFailure("Cannot fill an already-filled \(type(of: self))", file: file, line: line)
        }
    }
}

#if swift(>=3.2)
extension PromiseProtocol where Value == Void {
    /// Determines the promised event.
    ///
    /// Filling a deferred event should usually be attempted only once.
    ///
    /// - returns: Whether the promise was fulfilled.
    @discardableResult @available(swift 4)
    func fill() -> Bool {
        return fill(with: ())
    }
}
#endif
