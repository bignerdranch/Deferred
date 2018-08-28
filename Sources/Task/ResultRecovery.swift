//
//  ResultRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

extension TaskResult {
    /// Performs a coalescing operation, returning the result of unwrapping the
    /// success value of `result`, or `defaultValue` in case of an error.
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
    public static func ?? (result: TaskResult<Value>, defaultValue: @autoclosure() throws -> TaskResult<Value>) rethrows -> TaskResult<Value> {
        return try result.withValues(ifLeft: { _ in try defaultValue() }, ifRight: TaskResult.success)
    }
}
