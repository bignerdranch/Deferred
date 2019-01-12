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

// MARK: - Functional Transforms

extension Task.Result {
    /// Evaluates the `transform` for a success result, passing its unwrapped
    /// value as the parameter, to derive a new value.
    ///
    /// Use the `map` method with a closure that produces a new value.
    public func map<NewValue>(_ transform: (SuccessValue) -> NewValue) -> Task<NewValue>.Result {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the `transform` for a failure result, passing the unwrapped
    /// error as the parameter, to derive a new value.
    ///
    /// Use the `mapError` method with a closure that produces a new value.
    public func mapError(_ transform: (Error) -> Error) -> Task<SuccessValue>.Result {
        switch self {
        case .success(let success):
            return .success(success)
        case .failure(let failure):
            return .failure(transform(failure))
        }
    }

    /// Evaluates the `transform` for a success result, passing its unwrapped
    /// value as the parameter, to derive a new result.
    ///
    /// Use `flatMap` with a closure that itself returns a result.
    public func flatMap<NewValue>(_ transform: (SuccessValue) -> Task<NewValue>.Result) -> Task<NewValue>.Result {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the `transform` for a failure result, passing the unwrapped
    /// error as the parameter, to derive a new result.
    ///
    /// Use the `flatMapError` with a closure that itself returns a result.
    public func flatMapError(_ transform: (Error) -> Task<SuccessValue>.Result) -> Task<SuccessValue>.Result {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return transform(failure)
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
