//
//  TaskEveryMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/11/20.
//  Copyright © 2020 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension TaskProtocol {
    /// Returns a task that transparently performs the `eachUseTransform`
    /// using the original task.
    ///
    /// The `upon(_:execute:)`, `wait(until:)`, `cancel()`, etc. methods
    /// of the returned task forward to `self`, wrapping access to the underlying value
    /// by the transform.
    ///
    /// Though this method has a similar signature to `map`, it works differently by
    /// evaluating the `eachSuccessTransform` in whatever context the result
    /// of `self` is, without any guarantee of thread safety. Use this method to perform
    /// trivial code, such as unwrapping an optional.
    ///
    /// - see: `map(upon:transform:)`
    public func everySuccess<NewSuccess>(per eachSuccessTransform: @escaping(Success) -> NewSuccess) -> Task<NewSuccess> {
        let wrapped = every {
            Result(from: $0)
                .map(eachSuccessTransform)
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        if let progress = (self as? Task<Success>)?.progress {
            return Task<NewSuccess>(wrapped, progress: progress)
        }
        #endif

        return Task<NewSuccess>(wrapped, uponCancel: cancel)
    }
}
