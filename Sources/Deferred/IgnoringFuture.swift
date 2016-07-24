//
//  IgnoringFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// A wrapped future that discards the result of the future. The wrapped
/// future is determined when the underlying future is determined, but it
/// is always determined with the empty tuple. In this way, it models the
/// empty "completion" of some event.
///
/// This is semantically identical to the following:
///
///     myFuture.map { _ in }
///
/// But may behave more efficiently.
public struct IgnoringFuture<Base: FutureType>: FutureType {
    private let base: Base
    
    /// Creates a future that ignores the result of `base`.
    private init(_ base: Base) {
        self.base = base
    }

    /// Call some `body` closure once the event completes.
    ///
    /// If the event is already completed, the closure will be submitted to the
    /// `executor` immediately.
    public func upon(executor: ExecutorType, body: () -> Void) {
        base.upon(executor) { _ in body() }
    }
    
    /// Waits synchronously for the event to complete.
    ///
    /// If the event is already completed, the call returns immediately.
    ///
    /// - parameter time: A length of time to wait for event to complete.
    /// - returns: Nothing, if filled within the timeout, or `nil`.
    public func wait(time: Timeout) -> ()? {
        return base.wait(time).map { _ in }
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
    public func ignored() -> IgnoringFuture<Self> {
        return IgnoringFuture(self)
    }

}
