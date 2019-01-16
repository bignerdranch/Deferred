//
//  TaskPromise.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol where Self: PromiseProtocol {
    /// Completes the task with a successful `value`, or a thrown error.
    ///
    /// If `value` represents an expression that may fail by throwing, the
    /// task will implicitly catch the failure as the result.
    ///
    /// Fulfilling this deferred value should usually be attempted only once.
    ///
    /// - seealso: `PromiseProtocol.fill(with:)`
    @discardableResult
    public func succeed(with value: @autoclosure() throws -> Success) -> Bool {
        return fill(with: Value(catching: value))
    }

    /// Completes the task with a failed `error`.
    ///
    /// - see: fill(with:)
    @discardableResult
    public func fail(with error: Failure) -> Bool {
        return fill(with: Value(left: error))
    }
}

extension TaskProtocol where Self: PromiseProtocol, Success == Void {
    /// Completes the task with a success.
    ///
    /// Fulfilling this deferred value should usually be attempted only once.
    ///
    /// - seealso: `PromiseProtocol.fill(with:)`
    /// - seealso: `TaskProtocol.succeed(with:)`
    @discardableResult
    public func succeed() -> Bool {
        return fill(with: Value(right: ()))
    }
}
