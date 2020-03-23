//
//  TaskIgnore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/15/16.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol {
    /// Returns a task that ignores the successful completion of this task.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myTask.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: map(transform:)
    public func ignored() -> Task<Void> {
        return everySuccess { _ in }
    }
}
