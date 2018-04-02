//
//  FutureMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    /// Returns a future containing the result of mapping `transform` over the
    /// deferred value.
    public func map<NewValue>(upon executor: PreferredExecutor, transform: @escaping(Value) -> NewValue) -> Future<NewValue> {
        return map(upon: executor as Executor, transform: transform)
    }

    /// Returns a future containing the result of mapping `transform` over the
    /// deferred value.
    ///
    /// `map` submits the `transform` to the `executor` once the future's value
    /// is determined.
    ///
    /// - parameter executor: Context to execute the transformation on.
    /// - parameter transform: Creates something using the deferred value.
    /// - returns: A new future that is filled once the receiver is determined.
    public func map<NewValue>(upon executor: Executor, transform: @escaping(Value) -> NewValue) -> Future<NewValue> {
        let deferred = Deferred<NewValue>()
        upon(executor) {
            deferred.fill(with: transform($0))
        }
        return Future(deferred)
    }
}
