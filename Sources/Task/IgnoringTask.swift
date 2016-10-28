//
//  IgnoringTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/15/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif

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

extension Task {
    /// Returns a task that ignores the successful completion of this task.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myTask.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - see: map(transform:)
    public func ignored() -> Task<Void> {
        let future = Future(LazyMapFuture(self) { (result) -> TaskResult<Void> in
            result.withValues(ifLeft: TaskResult.failure, ifRight: { _ in TaskResult.success() })
        })

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<Void>(future: future, progress: progress)
#else
        return Task<Void>(future: future, cancellation: cancel)
#endif
    }
}
