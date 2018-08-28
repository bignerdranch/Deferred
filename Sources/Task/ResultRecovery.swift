//
//  ResultRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

extension TaskResult {
    /// Evaluates the `transform` for a success result, passing its unwrapped
    /// value as the parameter, to derive a new value.
    ///
    /// Use the `map` method with a closure that produces a new value.
    @_inlineable
    public func map<NewValue>(_ transform: (Value) throws -> NewValue) -> TaskResult<NewValue> {
        switch self {
        case .success(let value):
            do {
                return try .success(transform(value))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Evaluates the `transform` for a success result, passing its unwrapped
    /// value as the parameter, to derive a new result.
    ///
    /// Use `flatMap` with a closure that itself returns a result.
    @_inlineable
    public func flatMap<NewValue>(_ transform: (Value) throws -> TaskResult<NewValue>) -> TaskResult<NewValue> {
        switch self {
        case .success(let value):
            do {
                return try transform(value)
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension TaskResult {
    /// Performs a coalescing operation, returning the result of unwrapping the
    /// success value of `result`, or `defaultValue` in case of an error.
    @_inlineable
    public static func ?? (result: TaskResult<Value>, defaultValue: @autoclosure() throws -> Value) rethrows -> Value {
        switch result {
        case .success(let value):
            return value
        case .failure:
            return try defaultValue()
        }
    }

    /// Performs a coalescing operation, the wrapped success value `result`, or
    /// that of `defaultValue` in case of an error.
    @_inlineable
    public static func ?? (result: TaskResult<Value>, defaultValue: @autoclosure() throws -> TaskResult<Value>) rethrows -> TaskResult<Value> {
        return try result.withValues(ifLeft: { _ in try defaultValue() }, ifRight: TaskResult.success)
    }
}
