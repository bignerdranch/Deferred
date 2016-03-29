//
//  IgnoringFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// Note: This may look like a duplicate method, but this directly shadows the
// eager "map" on FutureType, breaking what is otherwise an ambiguity.
extension LazyFutureType where Value == UnderlyingFuture.Value {
    
    /// Returns a future that ignores the result of this future.
    public func ignore() -> LazyMapFuture<UnderlyingFuture, Void> {
        return map { _ in }
    }

}

extension LazyFutureType {

    /// Returns a future that ignores the result of this future.
    public func ignore() -> LazyMapFuture<Self, Void> {
        return map { _ in }
    }

}

extension FutureType {

    /// Returns a future that ignores the result of this future.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myFuture.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// - seealso: map(upon:_:)
    public func ignore() -> Future<Void> {
        return Future(lazy.ignore())
    }

}

@available(*, unavailable, message="Replaced with FutureType.ignore()")
public struct IgnoringFuture<Base: FutureType> {

    public init(_ base: Base) {
        fatalError("Cannot create unavailable type")
    }
}
