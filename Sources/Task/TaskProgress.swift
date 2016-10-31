//
//  NSProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

/// A progress object whose attributes reflect that of an external progress
/// tree.
private final class ProxyProgress: NSProgress {

    let observee: NSProgress
    var token: Observation?

    init(attachingTo observee: NSProgress) {
        let current = NSProgress.currentProgress()
        self.observee = observee
        super.init(parent: current, userInfo: nil)

        if current?.cancelled == true {
            observee.cancel()
        }

        if current?.paused == true {
            observee.pause()
        }

        token = Observation(observing: observee, observer: self)
    }

    deinit {
        token?.cancelObserving(observee)
        token = nil
    }

    func inheritCancelled(value: Bool) {
        if value {
            cancellationHandler = nil
            cancel()
        } else {
            cancellationHandler = observee.cancel
        }
    }

    func inheritPaused(value: Bool) {
        if value {
            pausingHandler = nil
            pause()
            if #available(OSX 10.11, iOS 9.0, *) {
                resumingHandler = observee.resume
            }
        } else if #available(OSX 10.11, iOS 9.0, *) {
            resumingHandler = nil
            resume()
            pausingHandler = observee.pause
        }
    }

    func inheritValue(value: AnyObject, forKeyPath keyPath: String) {
        setValue(value, forKeyPath: keyPath)
    }

    // MARK: - Derived values

    @objc static func keyPathsForValuesAffectingUserInfo() -> Set<String> {
        return [ "original.userInfo" ]
    }

    #if swift(>=2.3)
    override var userInfo: [String : AnyObject] {
        return observee.userInfo
    }
    #else
    override var userInfo: [NSObject : AnyObject] {
        return observee.userInfo
    }
    #endif

    override func setUserInfoObject(object: AnyObject?, forKey key: String) {
        observee.setUserInfoObject(object, forKey: key)
    }

    // MARK: - KVO babysitting

    /// A side-table object to weakify the progress observer and prevent
    /// delivery of notifications after deinit.
    final class Observation: NSObject {
        static let options: NSKeyValueObservingOptions = [.Initial, .New]
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
        }
        static var cancelledContext = false
        static var pausedContext = false
        static let attributes: [KeyPath] = [ .totalUnitCount, .completedUnitCount, .localizedDescription, .localizedAdditionalDescription, .cancellable, .pausable, .kind ]
        static var attributesContext = false

        struct State: OptionSetType {
            let rawValue: UInt32
            static let ready = State(rawValue: 1 << 0)
            static let observing = State(rawValue: 1 << 1)
            static let cancellable: State = [.ready, .observing]
            static let cancelled = State(rawValue: 1 << 2)
        }

        weak var observer: ProxyProgress?
        var state = State.ready.rawValue // see State

        init(observing observee: NSProgress, observer: ProxyProgress) {
            self.observer = observer
            super.init()

            for key in Observation.attributes {
                observee.addObserver(self, forKeyPath: key.rawValue, options: Observation.options, context: &Observation.attributesContext)
            }
            observee.addObserver(self, forKeyPath: KeyPath.cancelled.rawValue, options: Observation.options, context: &Observation.cancelledContext)
            observee.addObserver(self, forKeyPath: KeyPath.paused.rawValue, options: Observation.options, context: &Observation.pausedContext)

            OSAtomicOr32Barrier(State.observing.rawValue, &state)
        }

        func cancelObserving(observee: NSProgress) {
            let oldState = State(rawValue: UInt32(bitPattern: OSAtomicAnd32Orig(~State.ready.rawValue, &state)))
            guard !oldState.isStrictSupersetOf(.cancellable) else { return }
            OSAtomicOr32(State.cancelled.rawValue, &state)

            for key in Observation.attributes {
                observee.removeObserver(self, forKeyPath: key.rawValue, context: &Observation.attributesContext)
            }
            observee.removeObserver(self, forKeyPath: KeyPath.cancelled.rawValue, context: &Observation.cancelledContext)
            observee.removeObserver(self, forKeyPath: KeyPath.paused.rawValue, context: &Observation.pausedContext)
        }

        private override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
            guard let keyPath = keyPath where object != nil && (state & State.ready.rawValue) != 0, let observer = observer, newValue = change?[NSKeyValueChangeNewKey] else { return }
            switch context {
            case &Observation.cancelledContext:
                observer.inheritCancelled(newValue as! Bool)
            case &Observation.pausedContext:
                observer.inheritPaused(newValue as! Bool)
            case &Observation.attributesContext:
                observer.inheritValue(newValue, forKeyPath: keyPath)
            default:
                preconditionFailure("Unexpected KVO context for private object")
            }
        }
    }

}

extension NSProgress {
    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// Send `isOrphaned: false` if the iOS 9 behavior cannot be trusted (i.e.,
    /// `progress` is not understood to have no parent).
    @nonobjc func adoptChild(progress: NSProgress, orphaned canAdopt: Bool, pendingUnitCount: Int64) -> NSProgress {
        if #available(OSX 10.11, iOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
            return progress
        } else {
            let changedPendingUnitCount = NSProgress.currentProgress() === self
            if changedPendingUnitCount {
                resignCurrent()
            }

            becomeCurrentWithPendingUnitCount(pendingUnitCount)

            let progress = ProxyProgress(attachingTo: progress)

            if !changedPendingUnitCount {
                resignCurrent()
            }

            return progress
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
