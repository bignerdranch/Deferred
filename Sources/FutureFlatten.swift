//
//  FutureFlatten.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/17/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Dispatch

/// A combined view of a future that contains another future.
///
/// The determined value of this future is that of the innermost future when
/// both inner and outer futures are determined.
///
/// - note: To `flatten` itself is always lazy, but does not imply laziness
/// on algorithms applied to the result.  In other words:
/// * `future.flatten()` does not perform any operations
/// * `future.flatten().map(upon:_:)` maps eagerly, returning `Future`
/// * `future.lazy.flatten().map(_:)` maps lazily
public struct FlattenFuture<Base: FutureType where Base.Value: FutureType>: FutureType {

    private let base: Base
    private init(base: Base) {
        self.base = base
    }

    /// Call some function `body` once the inner and outer values become
    /// determined.
    ///
    /// If the innermost value is determined, the function will be submitted to
    /// the queue immediately. An upon call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue to execute the function `body` on.
    /// - parameter body: A function that uses the innermost delayed value.
    public func upon(queue: dispatch_queue_t, body: Base.Value.Value -> Void) {
        base.upon(queue) {
            $0.upon(queue, body: body)
        }
    }

    /// Waits synchronously, for a maximum `time`, for the innermost value to
    /// become available; otherwise, returns `nil`.
    public func wait(time: Timeout) -> Base.Value.Value? {
        return base.wait(.Now)?.wait(time)
    }

}

// Note: This may look like a duplicate method, but this directly shadows the
// eager "map" on FutureType, breaking what is otherwise an ambiguity.
extension LazyFutureType where Value: FutureType, Value == UnderlyingFuture.Value {

    /// A combined view of a lazy future that contains another future.
    ///
    /// - seealso: flatMap(_:)
    public func flatten() -> LazyFuture<FlattenFuture<UnderlyingFuture>> {
        return FlattenFuture(base: underlyingFuture).lazy
    }

}

extension LazyFutureType where Value: FutureType {

    /// A combined view of a lazy future that contains another future.
    ///
    /// - seealso: flatMap(_:)
    public func flatten() -> LazyFuture<FlattenFuture<Self>> {
        return FlattenFuture(base: self).lazy
    }

}

extension FutureType where Value: FutureType {

    /// A combined future that is determined with the value of the innermost
    /// future when both inner and outer futures are determined.
    ///
    /// - returns: The new future returned by combining these nested futures.
    /// - seealso: FutureType.Type.genericQueue
    /// - seealso: flatMap(_:)
    public func flatten() -> Future<Value.Value> {
        return Future(lazy.flatten())
    }

}
