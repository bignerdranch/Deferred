//
//  TaskAccumulator.swift
//  Deferred
//
//  Created by John Gallagher on 8/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

/// A tool to support waiting for a number tasks to complete.
///
/// `TaskAccumulator` can be incrementally given a number of tasks, an the
/// completion future will capture the current state of the accumulator.
///
/// The success or failure of the accumulated tasks is ignored - this type is
/// only interested in completion.
public struct TaskAccumulator {
    private let group = dispatch_group_create()

    /// Accumulate another task into the list of tasks that fold into the
    /// next `allCompleted()` task.
    ///
    /// This method is thread-safe.
    public func accumulate<Task: FutureType where Task.Value: ResultType>(task: Task) {
        dispatch_group_enter(group)
        task.upon { [group = group] _ in
            dispatch_group_leave(group)
        }
    }

    /// Generate a future which will be filled once all tasks currently given to
    /// this `TaskAccumulator` have completed.
    ///
    /// This method is thread-safe; however, there is an inherent race condition
    /// if this method is being called at the same time as `accumulate(_:)`.
    public func allCompleted() -> Future<Void> {
        let deferred = Deferred<Void>()
        dispatch_group_notify(group, Deferred<Void>.genericQueue) {
            deferred.fill()
        }
        return Future(deferred)
    }
}
