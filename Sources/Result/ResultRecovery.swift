//
//  ResultRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension ResultType {
    /// Creates a result with a successful `value`.
    public init(value getValue: @autoclosure() throws -> Value) {
        self.init { try getValue() }
    }

    /// Returns the success value or throws the error.
    public func extract() throws -> Value {
        return try withValues(ifSuccess: { $0 }, ifFailure: { throw $0 })
    }
}

/// Returns the success value of `left`, or `right` otherwise.
public func ?? <Left: ResultType>(left: Left, right: @autoclosure() throws -> Left.Value) rethrows -> Left.Value {
    return try left.withValues(ifSuccess: { $0 }, ifFailure: { _ in try right() })
}

/// Returns `left` if it is a success, or `right` otherwise.
public func ?? <Left: ResultType, Right: ResultType>(result: Left, recover: @autoclosure() throws -> Right) rethrows -> Right where Right.Value == Left.Value {
    return try result.withValues(ifSuccess: { Right(value: $0) }, ifFailure: { _ in try recover() })
}

/// This is an optional you probably don't want.
@available(*, unavailable, message: "Unexpected optional promotion. Please unwrap the Result first.")
public func ?? <Result: ResultType>(result: Result?, defaultValue: @autoclosure() throws -> Result.Value) rethrows -> Result.Value {
    fatalError("Cannot call unavailable methods")
}
