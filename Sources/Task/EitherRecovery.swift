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

    /// Performs a coalescing operation, returning the wrapped success value of
    /// `left` or a default value on the `right`.
    public static func ?? (left: Self, right: @autoclosure() throws -> Right) rethrows -> Right {
        return try left.withValues(ifLeft: { _ in try right() }, ifRight: { $0 })
    }

    /// Performs a coalescing operation, returning the success value of `lhs`
    /// or a default value on the `rhs`.
    public static func ?? <NewEither: Either>(lhs: Self, rhs: @autoclosure() throws -> NewEither) rethrows -> NewEither where NewEither.Right == Right {
        return try lhs.withValues(ifLeft: { _ in try rhs() }, ifRight: { NewEither(success: $0) })
    }
}

extension Either where Left == Error {
    /// Returns the success value or throws the error.
    public func extract() throws -> Right {
        return try withValues(ifLeft: { throw $0 }, ifRight: { $0 })
    }
}

extension Optional where Wrapped: Either {
    /// This is an optional conversion you probably don't want.
    @available(*, unavailable, message: "Unexpected optional promotion. Please unwrap the Result first.")
    public static func ?? (lhs: Wrapped?, rhs: @autoclosure() throws -> Wrapped.Right) rethrows -> Wrapped.Right {
        fatalError("Cannot call unavailable methods")
    }
}
