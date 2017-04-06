//
//  Either.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// A type that can exclusively represent either some result value of a
/// successful computation or a failure with an error.
public protocol Either: CustomStringConvertible, CustomDebugStringConvertible {
    associatedtype Left = Error
    associatedtype Right

    /// Derive a result from a failable function.
    init(from body: () throws -> Right)

    /// Creates a failed result with `error`.
    init(failure: Left)

    /// Case analysis.
    ///
    /// Returns the value from the `failure` closure if `self` represents a
    /// failure, or from the `success` closure if `self` represents a success.
    func withValues<Return>(ifLeft left: (Left) throws -> Return, ifRight right: (Right) throws -> Return) rethrows -> Return
}

extension Either {
    /// A textual representation of this instance.
    public var description: String {
        return withValues(ifLeft: { String(describing: $0) }, ifRight: { String(describing: $0) })
    }

    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        return withValues(ifLeft: {
            "failure(\(String(reflecting: $0)))"
        }, ifRight: {
            "success(\(String(reflecting: $0)))"
        })
    }
}
