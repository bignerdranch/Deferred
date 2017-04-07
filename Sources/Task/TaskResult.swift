//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// An enum for returning and propogating recoverable errors.
#if swift(>=3.1)
@available(*, deprecated, message: "Use Task.Result instead.")
public typealias TaskResult<SuccessValue> = Task<SuccessValue>.Result
#else
public enum TaskResult<SuccessValue> {
    /// Contains the success value
    case success(SuccessValue)
    /// Contains the error value
    case failure(Error)
}
#endif

extension TaskResult: Either {

    public typealias Value = SuccessValue

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
        case (let v?, _):
            // Ignore error if value is non-nil
            self = .success(v)
        case (nil, let e?):
            self = .failure(e)
        case (nil, nil):
            self = .failure(TaskResultInitializerError.invalidInput)
        }
    }
}

private enum TaskResultInitializerError: Error {
    case invalidInput
}
