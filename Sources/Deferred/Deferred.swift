//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value> {
    /// The primary storage, initialized with a value once-and-only-once (at
    /// init or later).
    private let variant: Variant

    public init() {
        variant = Variant()
    }

    /// Creates an instance resolved with `value`.
    public init(filledWith value: Value) {
        variant = Variant(for: value)
    }
}

extension Deferred: FutureProtocol {
    /// An enqueued handler.
    struct Continuation {
        let target: Executor?
        let handler: (Value) -> Void
    }

    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        let continuation = Continuation(target: executor, handler: body)
        variant.notify(continuation)
    }

    public func peek() -> Value? {
        return variant.load()
    }

    public func wait(until time: DispatchTime) -> Value? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Value?

        let continuation = Continuation(target: nil) { (value) in
            result = value
            semaphore.signal()
        }

        variant.notify(continuation)

        guard case .success = semaphore.wait(timeout: time) else { return nil }
        return result
    }
}

extension Deferred.Continuation {
    /// A continuation can be submitted to its passed-in executor or executed
    /// in the current context.
    func execute(with value: Value) {
        target?.submit {
            self.handler(value)
        } ?? handler(value)
    }
}

extension Deferred: PromiseProtocol {
    @discardableResult
    public func fill(with value: Value) -> Bool {
        return variant.store(value)
    }
}
