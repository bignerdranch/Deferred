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

extension PromiseProtocol where Value: ResultType {
    /// Completes the task with a successful `value`, or a thrown error.
    ///
    /// - seealso: `fill(_:)`
    @discardableResult
    public func succeed(_ value: @autoclosure() throws -> Value.Value) -> Bool {
        return fill(with: Value(value: value))
    }

    /// Completes the task with a failed `error`.
    ///
    /// - seealso: `fill(_:)`
    @discardableResult
    public func fail(_ error: Error) -> Bool {
        return fill(with: Value(error: error))
    }
}
