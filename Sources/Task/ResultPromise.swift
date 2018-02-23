//
//  ResultPromise.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension PromiseProtocol where Value: Either {
    /// Completes the task with a successful `value`, or a thrown error.
    ///
    /// - see: fill(with:)
    @discardableResult
    public func succeed(with value: @autoclosure() throws -> Value.Right) -> Bool {
        return fill(with: Value(from: value))
    }

    /// Completes the task with a failed `error`.
    ///
    /// - see: fill(with:)
    @discardableResult
    public func fail(with error: Value.Left) -> Bool {
        return fill(with: Value(failure: error))
    }
}

extension PromiseProtocol where Value: Either, Value.Right == Void {
    /// Notes the completion of the event with a success.
    @discardableResult @available(swift 4)
    public func succeed() -> Bool {
        return succeed(with: ())
    }
}
