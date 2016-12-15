//
//  TaskProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
import Atomics
import Deferred
import Result
#elseif XCODE
import Deferred.Atomics
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
/// A progress object whose attributes reflect that of an external progress
/// tree.
private final class ProxyProgress: Progress {

    private let observee: Progress
    private var token: Observation?

    init(attachingTo observee: Progress) {
        let current = Progress.current()
        self.observee = observee
        super.init(parent: current, userInfo: nil)

        if current?.isCancelled == true {
            observee.cancel()
        }

        if current?.isPaused == true {
            observee.pause()
        }

        token = Observation(observing: observee, observer: self)
    }

    deinit {
        token?.cancel(observing: observee)
        token = nil
    }

    private func inheritCancelled(_ value: Bool) {
        if value {
            cancellationHandler = nil
            cancel()
        } else {
            cancellationHandler = observee.cancel
        }
    }

    private func inheritPaused(_ value: Bool) {
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

    // MARK: - Derived values

    private func inheritValue(_ value: Any, forKeyPath keyPath: String) {
        setValue(value, forKeyPath: keyPath)
    }

    @objc static func keyPathsForValuesAffectingUserInfo() -> Set<String> {
        return [ "observee.userInfo" ]
    }

    override var userInfo: [ProgressUserInfoKey : Any] {
        return observee.userInfo
    }

    override func setUserInfoObject(_ objectOrNil: Any?, forKey key: ProgressUserInfoKey) {
        observee.setUserInfoObject(objectOrNil, forKey: key)
    }

    // MARK: - KVO babysitting

    /// A side-table object to weakify the progress observer and prevent
    /// delivery of notifications after deinit.
    private final class Observation: NSObject {
        private static let options: NSKeyValueObservingOptions = [.initial, .new]
        private static var cancelledContext = false
        private static var pausedContext = false
        private static let attributes = [
            #keyPath(Progress.completedUnitCount),
            #keyPath(Progress.totalUnitCount),
            #keyPath(Progress.localizedDescription),
            #keyPath(Progress.localizedAdditionalDescription),
            #keyPath(Progress.cancellable),
            #keyPath(Progress.pausable),
            #keyPath(Progress.kind)
        ]
        private static var attributesContext = false

        private struct State: OptionSet {
            let rawValue: UInt8
            static let ready = State(rawValue: 1 << 0)
            static let observing = State(rawValue: 1 << 1)
            static let cancellable: State = [.ready, .observing]
            static let cancelled = State(rawValue: 1 << 2)
        }

        private weak var observer: ProxyProgress?
        private var state = UnsafeAtomicBitmask() // see State

        init(observing observee: Progress, observer: ProxyProgress) {
            self.observer = observer
            state.setInitialValue(State.ready.rawValue)
            super.init()

            for key in Observation.attributes {
                observee.addObserver(self, forKeyPath: key, options: Observation.options, context: &Observation.attributesContext)
            }
            observee.addObserver(self, forKeyPath: #keyPath(Progress.cancelled), options: Observation.options, context: &Observation.cancelledContext)
            observee.addObserver(self, forKeyPath: #keyPath(Progress.paused), options: Observation.options, context: &Observation.pausedContext)

            state.or(with: State.observing.rawValue, order: .write)
        }

        func cancel(observing observee: Progress) {
            let oldState = State(rawValue: state.and(with: ~State.ready.rawValue, order: .none))
            guard !oldState.isStrictSuperset(of: .cancellable) else { return }
            state.or(with: State.cancelled.rawValue, order: .none)

            for key in Observation.attributes {
                observee.removeObserver(self, forKeyPath: key, context: &Observation.attributesContext)
            }
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.cancelled), context: &Observation.cancelledContext)
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.paused), context: &Observation.pausedContext)
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let keyPath = keyPath, object != nil, state.test(for: State.ready.rawValue), let observer = observer, let newValue = change?[.newKey] else { return }
            switch context {
            case (&Observation.cancelledContext)?:
                // Gotta trust KVO a little
                // swiftlint:disable:next force_cast
                observer.inheritCancelled(newValue as! Bool)
            case (&Observation.pausedContext)?:
                // Gotta trust KVO a little
                // swiftlint:disable:next force_cast
                observer.inheritPaused(newValue as! Bool)
            case (&Observation.attributesContext)?:
                observer.inheritValue(newValue, forKeyPath: keyPath)
            default:
                preconditionFailure("Unexpected KVO context for private object")
            }
        }
    }
}

extension Progress {
    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// Send `isOrphaned: false` if the iOS 9 behavior cannot be trusted (i.e.,
    /// `progress` is not understood to have no parent).
    @discardableResult
    @nonobjc func adoptChild(_ progress: Progress, orphaned canAdopt: Bool, pendingUnitCount: Int64) -> Progress {
        if #available(OSX 10.11, iOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
            return progress
        } else {
            let changedPendingUnitCount = Progress.current() === self
            if changedPendingUnitCount {
                resignCurrent()
            }

            becomeCurrent(withPendingUnitCount: pendingUnitCount)

            let progress = ProxyProgress(attachingTo: progress)

            if !changedPendingUnitCount {
                resignCurrent()
            }

            return progress
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
        let progress = Progress(parent: nil, userInfo: nil)
        progress.totalUnitCount = future.wait(until: .now()) != nil ? 0 : -1

        if let cancellation = cancellation {
            progress.cancellationHandler = cancellation
        } else {
            progress.isCancellable = false
        }

        let queue = DispatchQueue.global(qos: .utility)
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
        } else if let root = Progress.current(), let lock = root.userInfo[.taskRootLock] as? NSLock {
            // We're in a `extendingTask(unitCount:body:)` block, append it.
            lock.lock()
            defer { lock.unlock() }

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

#endif
