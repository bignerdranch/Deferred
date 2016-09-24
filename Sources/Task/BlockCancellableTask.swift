//
//  BlockCancellableTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 7/14/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

extension Task {
    /// Creates a Task around a unit of work `body` called on a `queue`.
    ///
    /// - parameter queue: A dispatch queue to perform the work on.
    /// - parameter options: Options controlling how `body` is executed upon
    ///   `queue` with respect to system resource contention.
    /// - parameter produceError: On cancel, this value is used to preemptively
    ///   complete the Task.
    /// - parameter body: A failable closure creating and returning the
    ///   success value of the task.
    /// - seealso: dispatch_block_flags_t
    public convenience init(upon queue: DispatchQueue = Task<SuccessValue>.genericQueue, per flags: DispatchWorkItemFlags = [], onCancel produceError: @autoclosure @escaping() -> Error, body: @escaping() throws -> SuccessValue) {
        let deferred = Deferred<Result>()
        let semaphore = DispatchSemaphore(value: 1)

        let block = DispatchWorkItem(flags: flags) {
            guard case .success = semaphore.wait(timeout: .now()) else { return }
            defer { semaphore.signal() }

            deferred.fill(Result(with: body))
        }

        queue.async(execute: block)

        self.init(deferred) {
            guard case .success = semaphore.wait(timeout: .now()) else { return }
            defer { semaphore.signal() }

            _ = deferred.fill(.failure(produceError()))
        }
    }
}
