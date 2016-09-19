//
//  TaskProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
import Result
import Deferred
#endif

// MARK: - Backports

private struct KVO {
    static var context = false
    enum KeyPath: String {
        case completedUnitCount
        case totalUnitCount
        case localizedDescription
        case localizedAdditionalDescription
        case cancellable
        case pausable
        case cancelled
        case paused
        case kind
        static let all: [KeyPath] = [ .totalUnitCount, .completedUnitCount, .localizedDescription, .localizedAdditionalDescription, .cancellable, .pausable, .cancelled, .paused, .kind ]
    }
}

/// A progress object whose attributes reflect that of an external progress
/// tree.
private final class ProxyProgress: Progress {
    let original: Progress

    init(cloning original: Progress) {
        self.original = original
        super.init(parent: .current(), userInfo: nil)
        attach()
    }

    deinit {
        detach()
    }

    func attach() {
        for keyPath in KVO.KeyPath.all {
            original.addObserver(self, forKeyPath: keyPath.rawValue, options: [.initial, .new], context: &KVO.context)
        }

        if Progress.current()?.isCancelled == true {
            original.cancel()
        } else {
            cancellationHandler = original.cancel
        }

        if Progress.current()?.isPaused == true {
            original.pause()
        } else {
            pausingHandler = original.pause
        }

        if #available(OSX 10.11, iOS 9.0, *) {
            resumingHandler = original.resume
        }
    }

    func detach() {
        for keyPath in KVO.KeyPath.all {
            original.removeObserver(self, forKeyPath: keyPath.rawValue, context: &KVO.context)
        }
    }

    private override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch (keyPath, context) {
        case (KVO.KeyPath.cancelled.rawValue?, (&KVO.context)?):
            guard change?[.newKey] as? Bool == true else { return }
            cancellationHandler = nil
            cancel()
        case (KVO.KeyPath.paused.rawValue?, (&KVO.context)?):
            if change?[.newKey] as? Bool == true {
                pausingHandler = nil
                pause()
                if #available(OSX 10.11, iOS 9.0, *) {
                    resumingHandler = original.resume
                }
            } else if #available(OSX 10.11, iOS 9.0, *) {
                resumingHandler = nil
                resume()
                pausingHandler = original.pause
            }
        case (let keyPath?, (&KVO.context)?):
            setValue(change?[.newKey], forKeyPath: keyPath)
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    @objc static func keyPathsForValuesAffectingUserInfo() -> Set<String> {
        return [ "original.userInfo" ]
    }

    override var userInfo: [ProgressUserInfoKey : Any] {
        return original.userInfo
    }

    override func setUserInfoObject(_ objectOrNil: Any?, forKey key: ProgressUserInfoKey) {
        original.setUserInfoObject(objectOrNil, forKey: key)
    }
}

extension Progress {
    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// Send `isOrphaned: false` if the iOS 9 behavior cannot be trusted (i.e.,
    /// `progress` is not understood to have no parent).
    @nonobjc func adoptChild(_ progress: Progress, orphaned canAdopt: Bool, pendingUnitCount: Int64) {
        if #available(OSX 10.11, iOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
        } else {
            let changedPendingUnitCount = Progress.current() === self
            if changedPendingUnitCount {
                resignCurrent()
            }

            becomeCurrent(withPendingUnitCount: pendingUnitCount)
            _ = ProxyProgress(cloning: progress)

            if !changedPendingUnitCount {
                resignCurrent()
            }
        }
    }
}

// MARK: - Convenience initializers

extension Progress {
    /// Indeterminate progress which will likely not change.
    @nonobjc static func indefinite() -> Self {
        let progress = self.init(parent: nil, userInfo: nil)
        progress.totalUnitCount = -1
        progress.isCancellable = false
        return progress
    }

    /// Progress for which no work actually needs to be done.
    @nonobjc static func noWork() -> Self {
        let progress = self.init(parent: nil, userInfo: nil)
        progress.totalUnitCount = 0
        progress.completedUnitCount = 1
        progress.isCancellable = false
        progress.isPausable = false
        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    @nonobjc static func wrapped<Future: FutureProtocol>(_ future: Future, cancellation: ((Void) -> Void)?) -> Progress where Future.Value: Either {
        if let task = future as? Task<Future.Value.Right> {
            return task.progress
        }
        
        let progress = Progress(parent: nil, userInfo: nil)
        progress.totalUnitCount = future.wait(until: .now()) != nil ? 0 : -1

        if let cancellation = cancellation {
            progress.cancellationHandler = cancellation
        } else {
            progress.isCancellable = false
        }

        let queue = DispatchQueue.global(qos: .background)
        future.upon(queue) { [weak progress] _ in
            progress?.totalUnitCount = 1
            progress?.completedUnitCount = 1
        }

        return progress
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

private extension ProgressUserInfoKey {
    static let taskRootLock = ProgressUserInfoKey(rawValue: "com_bignerdranch_Deferred_taskRootLock")
}

private extension Progress {
    /// `true` if the progress is a wrapper progress created by `Task<Value>`
    var isTaskRoot: Bool {
        return userInfo[.taskRootLock] != nil
    }

    /// Create a progress for the root of an implicit chain of tasks.
    convenience init(taskRootFor progress: Progress, orphaned: Bool) {
        self.init(parent: nil, userInfo: nil)
        totalUnitCount = 1
        setUserInfoObject(NSLock(), forKey: .taskRootLock)
        adoptChild(progress, orphaned: orphaned, pendingUnitCount: 1)
    }
}

extension Progress {
    /// Wrap or re-wrap `progress` if necessary, suitable for becoming the
    /// progress of a Task node.
    @nonobjc static func taskRoot(for progress: Progress) -> Progress {
        if progress.isTaskRoot || progress === Progress.current() {
            // Task<Value> has already taken care of this at a deeper level.
            return progress
        } else if let root = Progress.current().flatMap({ return $0.isTaskRoot ? $0 : nil }) {
            // We're in a `extendingTask(unitCount:body:)` block, append it.
            root.adoptChild(progress, orphaned: true, pendingUnitCount: 1)
            return root
        } else {
            // Otherwise, wrap it up as a Task<Value>-marked progress.
            return Progress(taskRootFor: progress, orphaned: true)
        }
    }
}

extension Task {
    /// Extend the progress of `self` to reflect an added operation of `cost`.
    ///
    /// Incrementing the total unit count is not atomic; we take a lock so as
    /// to not interfere with simultaneous mapping operations.
    func extendedProgress(byUnitCount cost: Int64) -> Progress {
        if let lock = progress.userInfo[.taskRootLock] as? NSLock {
            lock.lock()
            defer { lock.unlock() }

            progress.totalUnitCount += cost
            return progress
        } else {
            let progress = Progress(taskRootFor: self.progress, orphaned: false)

            progress.totalUnitCount += cost
            return progress
        }
    }
}
