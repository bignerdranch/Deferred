//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

/// A type that represents either a wrapped value or an error, representing the
/// possible return values of a throwing function.
public enum TaskResult<Value> {
    /// The success value, stored as `Value`.
    case success(Value)
    /// The failure value, stored as any error.
    case failure(Error)
}

// MARK: - Initializers

extension TaskResult {
    /// Creates an instance storing a successful `value`.
    @_inlineable
    public init(success value: @autoclosure() throws -> Value) {
        self.init(from: value)
    }

    /// Creates an instance storing an `error` describing the failure.
    @_inlineable
    public init(failure error: Error) {
        self = .failure(error)
    }

    /// Create an exclusive success/failure state derived from two optionals,
    /// in the style of Cocoa completion handlers.
    public init(value: Value?, error: Error?) {
        switch (value, error) {
        case (let value?, _):
            // Ignore error if value is non-nil
            self = .success(value)
        case (nil, let error?):
            self = .failure(error)
        case (nil, nil):
            self = .failure(TaskResultInitializerError.invalidInput)
        }
    }
}

private enum TaskResultInitializerError: Error {
    case invalidInput
}

extension TaskResult where Value == Void {
    /// Creates the success value.
    @_inlineable
    public init() {
        self = .success(())
    }
}

// MARK: - Compatibility with Protocol Extensions

extension TaskResult: Either {
    @_inlineable
    public init(left error: Error) {
        self = .failure(error)
    }

    @_inlineable
    public init(right value: Value) {
        self = .success(value)
    }

    @_inlineable
    public func withValues<Return>(ifLeft left: (Error) throws -> Return, ifRight right: (Value) throws -> Return) rethrows -> Return {
        switch self {
        case let .success(value):
            return try right(value)
        case let .failure(error):
            return try left(error)
        }
    }
}
