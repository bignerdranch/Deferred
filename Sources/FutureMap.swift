//
//  FutureMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureType {

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
    /// Transforms the future once it becomes determined.
    ///
    /// `map` executes a transform immediately when the future's value is
    /// determined.
    ///
    /// - parameter queue: Optional dispatch queue for executing the transform
    ///   from. Defaults to a global queue matching the current QoS.
    /// - parameter transform: Create something using the deferred value.
    /// - returns: A new future that is filled once the reciever is determined.
    /// - seealso: Deferred
    public func map<NewValue>(upon queue: dispatch_queue_t, _ transform: Value -> NewValue) -> Future<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            d.fill(transform($0))
        }
        return Future(d)
    }

    public func map<NewValue>(transform: Value -> NewValue) -> Future<NewValue> {
        return map(upon: Self.genericQueue, transform)
    }
}
