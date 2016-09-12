//
//  ResultPromise.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif

extension PromiseProtocol where Value: Either {
    /// Completes the task with a successful `value`, or a thrown error.
    ///
    /// - seealso: `fill(_:)`
    @discardableResult
    public func succeed(with value: @autoclosure() throws -> Value.Right) -> Bool {
        return fill(with: Value(with: value))
    }

    /// Completes the task with a failed `error`.
    ///
    /// - seealso: `fill(_:)`
    @discardableResult
    public func fail(with error: Value.Left) -> Bool {
        return fill(with: Value(failure: error))
    }
}
