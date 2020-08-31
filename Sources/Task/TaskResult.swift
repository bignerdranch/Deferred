//
//  TaskResult.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

// MARK: Compatibility with Protocol Extensions

extension Result: Either where Failure == Error {}

// MARK: - Initializers

private enum TaskResultInitializerError: Error {
    case invalidInput
}

extension Result where Failure == Error {
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
