//
//  TaskProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation
#if SWIFT_PACKAGE
import Deferred
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
extension Progress {
    /// A simple indeterminate progress with a cancellation function.
    static func wrappingSuccess<Wrapped: TaskProtocol>(of wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) -> Progress {
        switch (wrapped as? Task<Wrapped.SuccessValue>, cancellation) {
        case (let task?, nil):
            return task.progress
        case (let task?, let cancellation?):
            let progress = Progress(totalUnitCount: 1)
            progress.cancellationHandler = cancellation
            progress.monitorChild(task.progress, withPendingUnitCount: 1)
            return progress
        default:
            return .basicProgress(parent: .current(), for: wrapped, uponCancel: cancellation)
        }
    }
}

// MARK: - Task chaining

/**
 Both Task<Value> and NSProgress operate compose over implicit trees, but their
 ordering is reversed. You call map or flatMap on a Task to schedule follow-up
 work, which looks a lot like chaining; a progress tree has a parent-child
 approach. These are compatible: Task adopts progress instances given to it,
 creating a root node implicitly used by chaining calls.
 **/

private let taskRootLock = ProgressUserInfoKey(rawValue: "_DeferredTaskRootLock")
private let taskRootUnitCount = Int64(16)

extension Progress {
    /// Wrap or re-wrap `progress` if necessary, suitable for becoming the
    /// progress of a Task node.
    static func taskRoot(for inner: Progress) -> Progress {
        let current = Progress.current()
        if inner == current || inner.userInfo[taskRootLock] != nil {
            // Task<Value> has already taken care of this at a deeper level.
            return inner
        } else if let root = current, root.userInfo[taskRootLock] != nil {
            return root
        } else {
            // Otherwise, wrap it up as a Task<Value>-marked progress.
            let outer = Progress(totalUnitCount: taskRootUnitCount)
            outer.setUserInfoObject(NSLock(), forKey: taskRootLock)
            outer.adoptChild(inner, withPendingUnitCount: taskRootUnitCount)
            return outer
        }
    }
}

extension TaskProtocol {
    /// Extend the progress of `self` to reflect an added operation of `cost`.
    ///
    /// Incrementing the total unit count is not atomic; we take a lock so as
    /// to not interfere with simultaneous mapping operations.
    func preparedProgressForContinuedWork() -> Progress {
        let inner = Progress.wrappingSuccess(of: self)
        let continuedWorkUnitCount = Int64(1)
        if let lock = inner.userInfo[taskRootLock] as? NSLock {
            lock.lock()
            defer { lock.unlock() }

            inner.totalUnitCount += continuedWorkUnitCount
            return inner
        } else {
            let outer = Progress(totalUnitCount: taskRootUnitCount + continuedWorkUnitCount)
            outer.setUserInfoObject(NSLock(), forKey: taskRootLock)
            outer.monitorChild(inner, withPendingUnitCount: taskRootUnitCount)
            return outer
        }
    }
}
#endif
