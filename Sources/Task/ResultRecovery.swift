//
//  ResultRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

extension Task.Result {
    /// Evaluates the `transform` for a success result, passing its unwrapped
    /// value as the parameter, to derive a new value.
    ///
    /// Use the `map` method with a closure that produces a new value.
    public func map<NewValue>(_ transform: (SuccessValue) throws -> NewValue) -> Task<NewValue>.Result {
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
    public func flatMap<NewValue>(_ transform: (SuccessValue) throws -> Task<NewValue>.Result) -> Task<NewValue>.Result {
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
