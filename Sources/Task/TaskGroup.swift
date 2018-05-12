//
//  TaskGroup.swift
//  Deferred
//
//  Created by John Gallagher on 8/18/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

/// A tool to support waiting for a number tasks to complete.
///
/// `TaskGroup` can be incrementally given a number of tasks, and a completion
/// future will capture the current state of the group.
///
/// The success or failure of the accumulated tasks is ignored - this type is
/// only interested in completion.
public struct TaskGroup {

    private let group = DispatchGroup()

    /// Creates the empty task group.
    public init() {}

    private var queue: DispatchQueue {
        return .global(qos: .utility)
    }

    /// Accumulate another task into the list of tasks that fold into the
    /// next `allCompleted()` task.
    ///
    /// This method is thread-safe.
    public func include<Task: FutureProtocol>(_ task: Task)
        where Task.Value: Either {
        group.enter()
        task.upon(queue) { [group = group] _ in
            group.leave()
        }
    }

    /// Generate a future which will be filled once all tasks currently given to
    /// this `TaskGroup` have completed.
    ///
    /// This method is thread-safe; however, there is an inherent race condition
    /// if this method is being called at the same time as `accumulate(_:)`.
    public func completed() -> Future<Void> {
        let deferred = Deferred<Void>()
        group.notify(queue: queue) {
            deferred.fill(with: ())
        }
        return Future(deferred)
    }
}
