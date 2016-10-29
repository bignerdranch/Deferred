//
//  FutureLateMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Dispatch

/// A `FutureProtocol` whose determined element is that of a `Base` future passed
/// through a transform function returning `NewValue`. This value is computed
/// each time it is read through a call to `upon(queue:body:)`.
private struct LazyMapFuture<Base: FutureProtocol, NewValue>: FutureProtocol {
    let base: Base
    let transform: (Base.Value) -> NewValue
    fileprivate init(_ base: Base, transform: @escaping(Base.Value) -> NewValue) {
        self.base = base
        self.transform = transform
    }

    func upon(_ executor: Base.PreferredExecutor, execute body: @escaping(NewValue) -> Void) {
        return base.upon(executor) { [transform] in
            body(transform($0))
        }
    }

    func upon(_ executor: Executor, execute body: @escaping(NewValue) -> Void) {
        return base.upon(executor) { [transform] in
            body(transform($0))
        }
    }

    func wait(until time: DispatchTime) -> NewValue? {
        return base.wait(until: time).map(transform)
    }
}

extension FutureProtocol {
    /// Returns a future that transparently performs the `eachUseTransform`
    /// while reusing the original future.
    ///
    /// The `upon(_:execute:)` and `wait(until:)` methods of the returned future
    /// forward to `self`, wrapping access to the underlying value by the
    /// transform.
    ///
    /// Though producing similar results, this method does not work like `map`,
    /// which eagerly evaluates the transform to create a new future with new
    /// storage. This is not suitable for simple transforms, such as unboxing
    /// or conversion.
    ///
    /// - see: map(upon:transform:)
    public func every<NewValue>(per eachUseTransform: @escaping(Value) -> NewValue) -> Future<NewValue> {
        return Future(LazyMapFuture(self, transform: eachUseTransform))
    }
}
