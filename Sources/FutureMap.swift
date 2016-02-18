//
//  LazyMapFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/17/16.
//  Copyright © 2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A `FutureType` whose determined element is that of a `Base` future passed
/// through a transform function returning `NewValue`. This value is computed
/// each time it is read through a call to `upon(queue:body:)`.
public struct LazyMapFuture<Base: FutureType, NewValue>: LazyFutureType {

    private let base: Base
    private let transform: Base.Value -> NewValue
    private init(_ base: Base, transform: Base.Value -> NewValue) {
        self.base = base
        self.transform = transform
    }

    /// Call some function `body` once the value becomes determined.
    ///
    /// If the value is determined, the function will be submitted to the
    /// queue immediately. An upon call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue to execute the function `body` on.
    /// - parameter body: A function that uses the delayed value.
    public func upon(queue: dispatch_queue_t, body: NewValue -> Void) {
        return base.upon(queue) { [transform] in
            body(transform($0))
        }
    }

    /// Waits synchronously, for a maximum `time`, for the calculated value to
    /// become determined; otherwise, returns `nil`.
    public func wait(time: Timeout) -> NewValue? {
        return base.wait(time).map(transform)
    }

}

// Note: This may look like a duplicate method, but this directly shadows the
// eager "map" on FutureType, breaking what is otherwise an ambiguity.
extension LazyFutureType where Value == UnderlyingFuture.Value {

    /// Returns a `LazyMapFuture` over this `FutureType`. The value of the result
    /// is determined lazily, each time it is read, by calling a `transform` on
    /// the base value.
    public func map<NewValue>(transform: Value -> NewValue) -> LazyMapFuture<UnderlyingFuture, NewValue> {
        return .init(underlyingFuture, transform: transform)
    }

}

extension LazyFutureType {

    /// Returns a `LazyMapFuture` over this `FutureType`. The value of the result
    /// is determined lazily, each time it is read, by calling a `transform` on
    /// the base value.
    public func map<NewValue>(transform: Value -> NewValue) -> LazyMapFuture<Self, NewValue> {
        return .init(self, transform: transform)
    }

}

extension FutureType {

    /// Transforms the future once it becomes determined. The calculation is
    /// performed on a global queue matching the current quality-of-service.
    ///
    /// - parameter transform: Create something using the determined value.
    /// - returns: A new future that is filled after this one is determined.
    /// - seealso: map(upon:_:)
    public func map<NewValue>(transform: Value -> NewValue) -> Future<NewValue> {
        return map(upon: Self.genericQueue, transform)
    }

    /// Transforms the future once it becomes determined.
    ///
    /// - parameter queue: Dispatch queue for executing the transform from.
    /// - parameter transform: Create something using the determined value.
    /// - returns: A new future that is filled after this one is determined.
    public func map<NewValue>(upon queue: dispatch_queue_t, _ transform: Value -> NewValue) -> Future<NewValue> {
        let d = Deferred<NewValue>()
        lazy.map(transform).upon(queue) {
            d.fill($0)
        }
        return Future(d)
    }

}
