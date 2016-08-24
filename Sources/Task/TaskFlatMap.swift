//
//  TaskFlatMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

private func commonFlatMap<OldResult: ResultType, NewTask: TaskType>(startNextTask: OldResult.Value throws -> NewTask, cancellationToken: Deferred<Void>) -> (OldResult) -> Future<NewTask.Value> {
    return { result in
        do {
            let newTask = try startNextTask(result.extract())
            cancellationToken.upon(newTask.cancel)
            return Future(newTask)
        } catch {
            return Future(value: NewTask.Value(error: error))
        }
    }
}

extension TaskType {
    private typealias OldSuccessValue = Value.Value

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Cancelling the resulting task will attempt to cancel both the recieving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` submits `startNextTask` to `executor`
    /// once the task completes successfully.
    /// - seealso: FutureType.flatMap(upon:_:)
    public func flatMap<NewTask: TaskType>(upon executor: ExecutorType, _ startNextTask: OldSuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let cancellationToken = Deferred<Void>()
        let mapped = flatMap(upon: executor, commonFlatMap(startNextTask, cancellationToken: cancellationToken))
        return Task(mapped) { _ = cancellationToken.fill() }
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` executes `startNextTask`
    /// asynchronously once the task completes successfully.
    /// - seealso: flatMap(upon:_:)
    /// - seealso: FutureType.flatMap(upon:_:)
    public func flatMap<NewTask: TaskType>(upon queue: dispatch_queue_t, _ startNextTask: OldSuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let cancellationToken = Deferred<Void>()
        let mapped = flatMap(upon: queue, commonFlatMap(startNextTask, cancellationToken: cancellationToken))
        return Task(mapped) { _ = cancellationToken.fill() }
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `flatMap` executes `startNextTask` in the
    /// background once the task completes successfully.
    /// - seealso: flatMap(upon:_:)
    /// - seealso: FutureType.flatMap(_:)
    public func flatMap<NewTask: TaskType>(startNextTask: OldSuccessValue throws -> NewTask) -> Task<NewTask.Value.Value> {
        let cancellationToken = Deferred<Void>()
        let mapped = flatMap(commonFlatMap(startNextTask, cancellationToken: cancellationToken))
        return Task(mapped) { _ = cancellationToken.fill() }
    }
}
