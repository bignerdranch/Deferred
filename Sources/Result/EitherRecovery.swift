//
//  EitherRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension Either {
    /// Creates a result with a successful `value`.
    public init(success getValue: @autoclosure() throws -> Right) {
        self.init { try getValue() }
    }
}

extension Either where Left == Error {
    /// Returns the success value or throws the error.
    public func extract() throws -> Right {
        return try withValues(ifLeft: { throw $0 }, ifRight: { $0 })
    }
}

/// Returns the success value of `left`, or `right` otherwise.
public func ?? <Left: Either>(lhs: Left, rhs: @autoclosure() throws -> Left.Right) rethrows -> Left.Right {
    return try lhs.withValues(ifLeft: { _ in try rhs() }, ifRight: { $0 })
}

/// Returns `left` if it is a success, or `right` otherwise.
public func ?? <Left: Either, Right: Either>(result: Left, recover: @autoclosure() throws -> Right) rethrows -> Right where Right.Right == Left.Right {
    return try result.withValues(ifLeft: { _ in try recover() }, ifRight: { Right(success: $0) })
}

/// This is an optional you probably don't want.
@available(*, unavailable, message: "Unexpected optional promotion. Please unwrap the Result first.")
public func ?? <Left: Either>(result: Left?, defaultValue: @autoclosure() throws -> Left.Right) rethrows -> Left.Right {
    fatalError("Cannot call unavailable methods")
}
