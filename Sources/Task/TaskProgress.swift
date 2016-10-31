//
//  NSProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

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
private final class ProxyProgress: NSProgress {
    let original: NSProgress

    init(cloning original: NSProgress) {
        self.original = original
        super.init(parent: .currentProgress(), userInfo: nil)
    }

    deinit {
        detach()
    }

    func attach() {
        if NSProgress.currentProgress()?.cancelled == true {
            original.cancel()
        }

        if NSProgress.currentProgress()?.paused == true {
            original.pause()
        }

        for keyPath in KVO.KeyPath.all {
            original.addObserver(self, forKeyPath: keyPath.rawValue, options: [.Initial, .New], context: &KVO.context)
        }
    }

    func detach() {
        for keyPath in KVO.KeyPath.all {
            original.removeObserver(self, forKeyPath: keyPath.rawValue, context: &KVO.context)
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch (keyPath, context) {
        case (KVO.KeyPath.cancelled.rawValue?, &KVO.context):
            if change?[NSKeyValueChangeNewKey] as? Bool == true {
                cancellationHandler = nil
                cancel()
            } else {
                cancellationHandler = original.cancel
            }
        case (KVO.KeyPath.paused.rawValue?, &KVO.context):
            if change?[NSKeyValueChangeNewKey] as? Bool == true {
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
        case (let keyPath?, &KVO.context):
            setValue(change?[NSKeyValueChangeNewKey], forKeyPath: keyPath)
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    @objc static func keyPathsForValuesAffectingUserInfo() -> Set<String> {
        return [ "original.userInfo" ]
    }

    #if swift(>=2.3)
    override var userInfo: [String : AnyObject] {
        return original.userInfo
    }
    #else
    override var userInfo: [NSObject : AnyObject] {
        return original.userInfo
    }
    #endif

    override func setUserInfoObject(object: AnyObject?, forKey key: String) {
        original.setUserInfoObject(object, forKey: key)
    }
}

extension NSProgress {
    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// Send `isOrphaned: false` if the iOS 9 behavior cannot be trusted (i.e.,
    /// `progress` is not understood to have no parent).
    @nonobjc func adoptChild(progress: NSProgress, orphaned canAdopt: Bool, pendingUnitCount: Int64) {
        if #available(OSX 10.11, iOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
        } else {
            let changedPendingUnitCount = NSProgress.currentProgress() === self
            if changedPendingUnitCount {
                resignCurrent()
            }

            becomeCurrentWithPendingUnitCount(pendingUnitCount)

            let progress = ProxyProgress(cloning: progress)
            progress.attach()

            withExtendedLifetime(progress) {
                if !changedPendingUnitCount {
                    resignCurrent()
                }
            }
        }
    }
}

// MARK: - Convenience initializers

extension NSProgress {
    /// Indeterminate progress which will likely not change.
    @nonobjc static func indefinite() -> Self {
        let progress = self.init(parent: nil, userInfo: nil)
        progress.totalUnitCount = -1
        progress.cancellable = false
        return progress
    }

    /// Progress for which no work actually needs to be done.
    @nonobjc static func noWork() -> Self {
        let progress = self.init(parent: nil, userInfo: nil)
        progress.totalUnitCount = 0
        progress.completedUnitCount = 1
        progress.cancellable = false
        progress.pausable = false
        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    @nonobjc static func wrapped<Future: FutureType where Future.Value: ResultType>(future: Future, cancellation: ((Void) -> Void)?) -> NSProgress {
        if let task = future as? Task<Future.Value.Value> {
            return task.progress
        }

        let progress = NSProgress(parent: nil, userInfo: nil)
        progress.totalUnitCount = future.isFilled ? 0 : -1

        if let cancellation = cancellation {
            progress.cancellationHandler = cancellation
        } else {
            progress.cancellable = false
        }

        let queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
        future.upon(queue) { _ in
            progress.totalUnitCount = 1
            progress.completedUnitCount = 1
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

private let NSProgressTaskRootLockKey = "com_bignerdranch_Deferred_taskRootLock"

private extension NSProgress {
    /// `true` if the progress is a wrapper progress created by `Task<Value>`
    var isTaskRoot: Bool {
        return userInfo[NSProgressTaskRootLockKey] != nil
    }

    /// Create a progress for the root of an implicit chain of tasks.
    convenience init(taskRootFor progress: NSProgress, orphaned: Bool) {
        self.init(parent: nil, userInfo: nil)
        totalUnitCount = 1
        setUserInfoObject(NSLock(), forKey: NSProgressTaskRootLockKey)
        adoptChild(progress, orphaned: orphaned, pendingUnitCount: 1)
    }
}

extension NSProgress {
    /// Wrap or re-wrap `progress` if necessary, suitable for becoming the
    /// progress of a Task node.
    @nonobjc static func taskRoot(for progress: NSProgress) -> NSProgress {
        if progress.isTaskRoot || progress === NSProgress.currentProgress() {
            // Task<Value> has already taken care of this at a deeper level.
            return progress
        } else if let root = NSProgress.currentProgress(), lock = root.userInfo[NSProgressTaskRootLockKey] as? NSLock {
            // We're in a `extendingTask(unitCount:body:)` block, append it.
            lock.lock()
            defer { lock.unlock() }

            root.adoptChild(progress, orphaned: true, pendingUnitCount: 1)
            return root
        } else {
            // Otherwise, wrap it up as a Task<Value>-marked progress.
            return NSProgress(taskRootFor: progress, orphaned: true)
        }
    }
}

extension Task {
    /// Extend the progress of `self` to reflect an added operation of `cost`.
    ///
    /// Incrementing the total unit count is not atomic; we take a lock so as
    /// to not interfere with simultaneous mapping operations.
    func extendedProgress(byUnitCount cost: Int64) -> NSProgress {
        if let lock = progress.userInfo[NSProgressTaskRootLockKey] as? NSLock {
            lock.lock()
            defer { lock.unlock() }

            progress.totalUnitCount += cost
            return progress
        } else {
            let progress = NSProgress(taskRootFor: self.progress, orphaned: false)

            progress.totalUnitCount += cost
            return progress
        }
    }
}
