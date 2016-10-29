//
//  FutureIgnore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 9/3/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    /// Returns a future that ignores the result of this future.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myFuture.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// - see: map(upon:transform:)
    public func ignored() -> Future<Void> {
        return every { _ in }
    }
}
