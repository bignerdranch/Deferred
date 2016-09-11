//
//  ResultType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// A type that can exclusively represent either some result value of a
/// successful computation or a failure with an error.
public protocol ResultType: CustomStringConvertible, CustomDebugStringConvertible {
    associatedtype Value

    /// Derive a result from a failable function.
    init(with body: () throws -> Value)

    /// Creates a failed result with `error`.
    init(error: Error)

    /// Case analysis.
    ///
    /// Returns the value from the `failure` closure if `self` represents a
    /// failure, or from the `success` closure if `self` represents a success.
    func withValues<Return>(ifSuccess success: (Value) throws -> Return, ifFailure failure: (Error) throws -> Return) rethrows -> Return
}

extension ResultType {
    /// A textual representation of `self`.
    public var description: String {
        return withValues(ifSuccess: { String(describing: $0) }, ifFailure: { String(describing: $0) })
    }

    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        return withValues(ifSuccess: {
            "success(\(String(reflecting: $0)))"
        }, ifFailure: {
            "failure(\(String(reflecting: $0)))"
        })
    }
}
