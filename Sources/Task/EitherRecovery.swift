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

/// Performs a coalescing operation, returning the wrapped success value of
/// `left` or a default value on the `right`.
public func ?? <Left: Either>(left: Left, right: @autoclosure() throws -> Left.Right) rethrows -> Left.Right {
    return try left.withValues(ifLeft: { _ in try right() }, ifRight: { $0 })
}

/// Performs a coalescing operation, returning the wrapped success value of
/// `left` or a default value on the `right`.
public func ?? <Left: Either, Right: Either>(left: Left, right: @autoclosure() throws -> Right) rethrows -> Right where Right.Right == Left.Right {
    return try left.withValues(ifLeft: { _ in try right() }, ifRight: { Right(success: $0) })
}

/// This is an optional you probably don't want.
@available(*, unavailable, message: "Unexpected optional promotion. Please unwrap the Result first.")
public func ?? <Left: Either>(left: Left?, right: @autoclosure() throws -> Left.Right) rethrows -> Left.Right {
    fatalError("Cannot call unavailable methods")
}
