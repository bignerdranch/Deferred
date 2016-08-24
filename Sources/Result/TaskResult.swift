//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// An enum for returning and propogating recoverable errors.
public enum TaskResult<Value> {
    /// Contains the success value
    case Success(Value)
    /// Contains the error value
    case Failure(ErrorType)
}

extension TaskResult: ResultType {
    /// Creates a result with a successful `value`.
    public init(@noescape with body: () throws -> Value) {
        do {
            self = try .Success(body())
        } catch {
            self = .Failure(error)
        }
    }

    /// Creates a failed result with `error`.
    public init(error: ErrorType) {
        self = .Failure(error)
    }

    /// Case analysis.
    ///
    /// Returns the value from the `failure` closure if `self` represents a
    /// failure, or from the `success` closure if `self` represents a success.
    public func withValues<Return>(@noescape ifSuccess success: Value throws -> Return, @noescape ifFailure failure: ErrorType throws -> Return) rethrows -> Return {
        switch self {
        case let .Success(value): return try success(value)
        case let .Failure(error): return try failure(error)
        }
    }
}
