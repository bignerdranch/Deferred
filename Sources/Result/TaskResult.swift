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

extension TaskResult: Either {
    public init(from body: () throws -> Value) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }

    public init(failure error: Error) {
        self = .failure(error)
    }

    public func withValues<Return>(ifLeft left: (Error) throws -> Return, ifRight right: (Value) throws -> Return) rethrows -> Return {
        switch self {
        case let .success(value): return try right(value)
        case let .failure(error): return try left(error)
        }
    }
}
