//
//  Promise.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension Deferred {
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
    @inlinable
    public func mustFill(with value: Value, file: StaticString = #file, line: UInt = #line) {
        precondition(fill(with: value), "Cannot fill an already-filled \(type(of: self)) using \(#function)", file: file, line: line)
    }
}

extension Deferred where Value == Void {
    /// Determines the promised event.
    ///
    /// Filling a deferred event should usually be attempted only once.
    ///
    /// - returns: Whether the promise was fulfilled.
    @discardableResult
    @inlinable
    func fill() -> Bool {
        return fill(with: ())
    }
}
