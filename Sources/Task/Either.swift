//
//  Either.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

/// A type that can exclusively represent one of two values.
///
/// By design, an either symmetrical and treats its variants the same way.
/// For representing success and failures, use `TaskResult`.
///
/// This protocol describes a minimal interface for representing `TaskResult`
/// to overcome limitations with Swift protocol extensions. It is expected that
/// its use will be removed completely at some later point.
@available(swift, deprecated: 100000)
public protocol Either {
    /// One of the two possible results.
    ///
    /// By convention, the left side is used to hold an error value.
    associatedtype Left = Error

    /// Creates a left-biased instance.
    init(left: Left)

    /// One of the two possible results.
    ///
    /// By convention, the right side is used to hold a correct value.
    associatedtype Right

    /// Creates a right-biased instance.
    init(right: Right)

    /// Case analysis.
    ///
    /// Returns the value from calling `left` if `self` is left-biased, or
    /// from calling `right` if `self` is right-biased.
    func withValues<Return>(ifLeft left: (Left) throws -> Return, ifRight right: (Right) throws -> Return) rethrows -> Return
}

extension Either where Left == Error {
    /// Derive a success value by calling a failable function `body`.
    public init(from body: () throws -> Right) {
        do {
            try self.init(right: body())
        } catch {
            self.init(left: error)
        }
    }

    /// Returns the success value or throws the error.
    public func extract() throws -> Right {
        return try withValues(ifLeft: { throw $0 }, ifRight: { $0 })
    }
}
