//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

// MARK: - Unwrapping

extension Task.Result {
    @_inlineable
    public func get() throws -> SuccessValue {
        switch self {
        case let .success(success):
            return success
        case let .failure(failure):
            throw failure
        }
    }
}

// MARK: - Initializers

extension Task.Result {
    /// Creates an instance storing a successful `value`.
    @_inlineable
    public init(success value: @autoclosure() throws -> SuccessValue) {
        self.init(catching: value)
    }

    /// Creates an instance storing an `error` describing the failure.
    @_inlineable
    public init(failure error: Error) {
        self = .failure(error)
    }

    /// Create an exclusive success/failure state derived from two optionals,
    /// in the style of Cocoa completion handlers.
    public init(value: SuccessValue?, error: Error?) {
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

extension Task.Result where SuccessValue == Void {
    /// Creates the success value.
    @_inlineable
    public init() {
        self = .success(())
    }
}

// MARK: - Compatibility with Protocol Extensions

extension Task.Result: Either {
    @_inlineable
    public init(left error: Error) {
        self = .failure(error)
    }

    @_inlineable
    public init(right value: SuccessValue) {
        self = .success(value)
    }
}
