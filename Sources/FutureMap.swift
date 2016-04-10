//
//  FutureMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureType {
    /// Returns a future containing the result of mapping `transform` over the
    /// deferred value.
    ///
    /// `map` submits the `transform` to the `executor` once the future's value
    /// is determined.
    ///
    /// - parameter executor: Context to execute the transformation on.
    /// - parameter transform: Creates something using the deferred value.
    /// - returns: A new future that is filled once the receiver is determined.
    public func map<NewValue>(upon executor: ExecutorType, _ transform: Value -> NewValue) -> Future<NewValue> {
        let d = Deferred<NewValue>()
        upon(executor) {
            d.fill(transform($0))
        }
        return Future(d)
    }
}

import Dispatch

extension FutureType {
    /// Returns a future containing the result of mapping `transform` over the
    /// deferred value.
    ///
    /// `map` executes the `transform` asynchronously when the future's value
    /// is determined.
    ///
    /// - parameter queue: Dispatch queue for calling the `transform`.
    /// - parameter transform: Creates something using the deferred value.
    /// - returns: A new future that is filled once the receiver is determined.
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewValue>(upon queue: dispatch_queue_t, _ transform: Value -> NewValue) -> Future<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            d.fill(transform($0))
        }
        return Future(d)
    }

    /// Returns a future containing the result of mapping `transform` over the
    /// deferred value.
    ///
    /// `map` executes the `transform` asynchronously executed on a global queue
    /// matching the current quality-of-service value.
    ///
    /// - parameter queue: Dispatch queue for calling the `transform`.
    /// - parameter transform: Creates something using the deferred value.
    /// - returns: A new future that is filled once the receiver is determined.
    /// - seealso: qos_class_t
    /// - seealso: FutureType.map(upon:_:)
    public func map<NewValue>(transform: Value -> NewValue) -> Future<NewValue> {
        return map(upon: Self.genericQueue, transform)
    }
}
