//
//  FutureAsync.swift
//  Deferred
//
//  Created by Zachary Waldowski on 6/3/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension Future {
    /// Captures the value of asynchronously executing `work` on `queue`.
    ///
    /// - parameter queue: A dispatch queue to perform the `work` on.
    /// - parameter flags: Options controlling how the `work` is executed with
    ///   respect to system resources.
    /// - parameter work: A function body that calculates and returns the
    ///   fulfilled value for the future.
    public static func async(upon queue: DispatchQueue = .any(), flags: DispatchWorkItemFlags = [], execute work: @escaping() -> Value) -> Future {
        let deferred = Deferred<Value>()

        queue.async(flags: flags) {
            deferred.fill(with: work())
        }

        return Future(deferred)
    }
}
