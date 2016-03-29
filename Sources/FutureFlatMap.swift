//
//  FutureFlatMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/17/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Dispatch

extension LazyFutureType where Value == UnderlyingFuture.Value {

    /// Returns a combined view of a future that begins another asynchronous
    /// operation with the result of some first operation.
    ///
    /// The second operation is not created if the result is never used.
    public func flatMap<NewFuture: FutureType>(transform: Value -> NewFuture) -> LazyFuture<FlattenFuture<LazyMapFuture<UnderlyingFuture, NewFuture>>> {
        return map(transform).flatten()
    }

}

extension LazyFutureType {

    /// Returns a combined view of a future that begins another asynchronous
    /// operation with the result of some first operation.
    ///
    /// The second operation is not created if the result is never used.
    public func flatMap<NewFuture: FutureType>(transform: Value -> NewFuture) -> LazyFuture<FlattenFuture<LazyMapFuture<Self, NewFuture>>> {
        return map(transform).flatten()
    }
    
}

extension FutureType {

    /// Begins another asynchronous operation with this delayed value, once it
    /// becomes determined.
    ///
    /// The new future is created on a on a global queue matching the current
    /// quality-of-service.
    ///
    /// - parameter transform: Begin a new operation using the deferred value.
    /// - returns: A new deferred value as returned by the `transform`.
    /// - seealso: flatMap(upon:_:)
    public func flatMap<NewFuture: FutureType>(transform: Value -> NewFuture) -> Future<NewFuture.Value> {
        return flatMap(upon: Self.genericQueue, transform)
    }

    /// Begins another asynchronous operation with this delayed value, once it
    /// becomes determined.
    ///
    /// `flatMap` is similar to `map`; use `flatMap` when you want this delayed
    /// value to feed into another asynchronous operation. You might hear this
    /// referred to as "chaining" or "binding".
    ///
    /// - important: The new future is created on another queue than that of the
    ///   caller. Keep this in mind for multithreading; a user of the determined
    ///   value might expect to be called from a certain queue.
    ///
    /// Equivalent to `map(transform).flatten()`, but more efficient.
    ///
    /// - parameter queue: Optional dispatch queue for starting the new
    ///   operation from.
    /// - parameter transform: Begin a new operation using the deferred value.
    /// - returns: A new deferred value as returned by the `transform`.
    /// - seealso: flatten()
    public func flatMap<NewFuture: FutureType>(upon queue: dispatch_queue_t, _ transform: Value -> NewFuture) -> Future<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        let mapped = lazy.map(transform).flatten()
        mapped.upon(queue) {
            d.fill($0)
        }
        return .init(d)
    }

}
