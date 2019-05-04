//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

// MARK: Compatibility with Protocol Extensions

extension Task.Result: Either {
    @inlinable
    public init(left error: Failure) {
        self = .failure(error)
    }

    @inlinable
    public init(right value: Success) {
        self = .success(value)
    }

    @inlinable
    public init(catching body: () throws -> Success) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }
}

// MARK: - Unwrapping

extension Task.Result {
    @inlinable
    public func get() throws -> Success {
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
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> Task<NewSuccess>.Result {
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
    public func mapError(_ transform: (Failure) -> Error) -> Task<Success>.Result {
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
    public func flatMap<NewSuccess>(_ transform: (Success) -> Task<NewSuccess>.Result) -> Task<NewSuccess>.Result {
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
    public func flatMapError(_ transform: (Failure) -> Task<Success>.Result) -> Task<Success>.Result {
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
    @inlinable
    public init(success value: @autoclosure() throws -> Success) {
        self.init(catching: value)
    }

    /// Creates an instance storing an `error` describing the failure.
    @inlinable
    public init(failure error: Failure) {
        self = .failure(error)
    }

    /// Create an exclusive success/failure state derived from two optionals,
    /// in the style of Cocoa completion handlers.
    public init(value: Success?, error: Failure?) {
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

extension Task.Result where Success == Void {
    /// Creates the success value.
    @inlinable
    public init() {
        self = .success(())
    }
}
