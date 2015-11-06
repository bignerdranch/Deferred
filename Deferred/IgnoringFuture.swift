//
//  IgnoringFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// Concrete future wrapper given an instance of a `FutureType`, but masks its
// value.
private final class IgnoredFutureBox<Future: FutureType>: FutureBoxBase<Void> {
    let base: Future
    init(base: Future) {
        self.base = base
        super.init()
    }

    override func upon(queue: dispatch_queue_t, body: () -> ()) {
        return base.upon(queue) { _ in body() }
    }

    override func wait(time: Timeout) -> ()? {
        return base.wait(time).map { _ in }
    }

}

public extension FutureType {
    /// A wrapped future that discards the result of the future. The wrapped
    /// future is determined when the underlying future is determined, but it
    /// is always determined with the empty tuple.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myFuture.map { _ in }
    ///
    /// But will behave more efficiently.
    var ignoringValue: AnyFuture<Void> {
        return AnyFuture(IgnoredFutureBox(base: self))
    }
}
