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
    case success(Value)
    /// Contains the error value
    case failure(Error)
}

extension TaskResult: ResultType {
    /// Creates a result with a successful `value`.
    public init(with body: () throws -> Value) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }

    /// Creates a failed result with `error`.
    public init(error: Error) {
        self = .failure(error)
    }

    /// Case analysis.
    ///
    /// Returns the value from the `failure` closure if `self` represents a
    /// failure, or from the `success` closure if `self` represents a success.
    public func withValues<Return>(ifSuccess success: (Value) throws -> Return, ifFailure failure: (Error) throws -> Return) rethrows -> Return {
        switch self {
        case let .success(value): return try success(value)
        case let .failure(error): return try failure(error)
        }
    }
}
