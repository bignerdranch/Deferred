//
//  LazyFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/17/16.
//  Copyright © 2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A wrapped future on which normally-eager operations such as `map` are
/// implemented lazily.
///
/// Lazy futures can be used to avoid needless creation of `Deferred` to reflect
/// a simple computation, because they wrap another future and perform
/// calculations on demand. For example,
///
///     someIntDeferred.lazy.map { Double($0 * 2) }
///
/// is now a `FutureType` eventually resolving to a doubled `Double`. Each
/// `upon` or `wait` is transformed on-the-fly.
///
/// To create a lazy future operation, extend this protocol to return types
/// that are themselves lazy futures.
///
/// - seealso: LazyFuture
public protocol LazyFutureType: FutureType {

    /// A `FutureType` that will resolve to the same `Value` as `self`,
    /// hopefully with a simpler type.
    ///
    /// - seealso: underlyingFuture
    associatedtype UnderlyingFuture: FutureType = Self

    /// A future resolving to the same value as `self`, hopefully with a simpler
    /// type.
    ///
    /// By default, returns `self`.
    var underlyingFuture: UnderlyingFuture { get }

}

extension LazyFutureType where UnderlyingFuture == Self {

    /// Identical to `self`.
    public var underlyingFuture: Self {
        return self
    }

}

extension FutureType where Self: LazyFutureType, Self.Value == Self.UnderlyingFuture.Value {

    /// Call some function `body` once the value becomes determined.
    ///
    /// If the value is determined, the function will be submitted to the
    /// queue immediately. An upon call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue to execute the function `body` on.
    /// - parameter body: A function that uses the determined value.
    public func upon(queue: dispatch_queue_t, body: Value -> Void) {
        return underlyingFuture.upon(queue, body: body)
    }

    /// Waits synchronously, for a maximum `time`, for the value to become
    /// determined; otherwise, returns `nil`.
    public func wait(time: Timeout) -> Value? {
        return underlyingFuture.wait(time)
    }

}

/// A future resolving to the same `Value` as a `Base` future, but on which
/// some operations should be implemented lazily.
///
/// - seealso: LazyFutureType
public struct LazyFuture<Base: FutureType>: LazyFutureType {

    public typealias Value = Base.Value

    /// The wrapped future.
    public let underlyingFuture: Base

    /// Creates a future that wraps `base`.
    private init(base underlyingFuture: Base) {
        self.underlyingFuture = underlyingFuture
    }

}

extension FutureType {

    /// A future resolving to the same `Value` as this one, but on which some
    /// operations can be done lazily.
    ///
    /// - seealso: LazyFuture
    public var lazy: LazyFuture<Self> {
        return .init(base: self)
    }

}

extension LazyFutureType {

    /// Identical to `self`.
    public var lazy: Self {
        return self
    }

}
