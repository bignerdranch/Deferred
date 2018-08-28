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
    @available(swift 4)
    public init() {
        self = .success(())
    }

}
