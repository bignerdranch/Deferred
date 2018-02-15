//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension Task.Result: Either {

    public init(from body: () throws -> SuccessValue) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }

    public init(failure error: Error) {
        self = .failure(error)
    }

    public func withValues<Return>(ifLeft left: (Error) throws -> Return, ifRight right: (SuccessValue) throws -> Return) rethrows -> Return {
        switch self {
        case let .success(value): return try right(value)
        case let .failure(error): return try left(error)
        }
    }

    /// Create an exclusive success/failure state derived from two optionals,
    /// in the style of Cocoa completion handlers.
    public init(value: SuccessValue?, error: Error?) {
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

extension Task.Result where SuccessValue == Void {

    /// Creates the success value.
    @available(swift 4)
    public init() {
        self = .success(())
    }

}

