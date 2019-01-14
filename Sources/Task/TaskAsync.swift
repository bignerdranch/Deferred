//
//  TaskAsync.swift
//  Deferred
//
//  Created by Zachary Waldowski on 7/14/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

extension Task {
    /// Captures the result of asynchronously executing `work` on `queue`.
    ///
    /// Canceling the returned task will not race with the contents of `work`.
    /// Once it begins to run, canceling will have no effect.
    ///
    /// - parameter queue: A dispatch queue to perform the `work` on.
    /// - parameter flags: Options controlling how the `work` is executed with
    ///   respect to system resources.
    /// - parameter produceError: Upon cancellation, this value is used to
    ///   preemptively fail the task.
    /// - parameter body: A function body that either calculates and returns the
    ///   success value for the task or throws to indicate failure.
    public static func async(upon queue: DispatchQueue = .any(), flags: DispatchWorkItemFlags = [], onCancel makeError: @autoclosure @escaping() -> Failure, execute work: @escaping() throws -> Success) -> Task {
        let deferred = Deferred<Result>()
        let semaphore = DispatchSemaphore(value: 1)

        queue.async(flags: flags) {
            guard case .success = semaphore.wait(timeout: .now()) else { return }
            defer { semaphore.signal() }

            deferred.fill(with: Result(catching: work))
        }

        return Task(deferred) {
            guard case .success = semaphore.wait(timeout: .now()) else { return }
            defer { semaphore.signal() }

            deferred.fail(with: makeError())
        }
    }

    @available(*, unavailable, message: "Replace with 'Task.async(upon:flags:onCancel:)' for clarity.")
    public convenience init(upon queue: DispatchQueue = .any(), flags: DispatchWorkItemFlags = [], onCancel produceError: @autoclosure @escaping() -> Error, execute body: @escaping() throws -> Success) {
        fatalError()
    }
}
