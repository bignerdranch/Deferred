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

extension dispatch_block_flags_t: OptionSetType {}

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
    public convenience init(upon queue: dispatch_queue_t = Task<SuccessValue>.genericQueue, per options: dispatch_block_flags_t = [], @autoclosure(escaping) onCancel produceError: () -> ErrorType, body: () throws -> SuccessValue) {
        let deferred = Deferred<Result>()
        let semaphore = dispatch_semaphore_create(1)

        let block = dispatch_block_create(options) {
            guard dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0 else { return }
            defer { dispatch_semaphore_signal(semaphore) }

            deferred.fill(Result(with: body))
        }

        dispatch_async(queue, block)

        self.init(deferred) {
            guard dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0 else { return }
            defer { dispatch_semaphore_signal(semaphore) }

            _ = deferred.fill(.Failure(produceError()))
        }
    }
}
