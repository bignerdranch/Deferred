//
//  TaskProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation
#if SWIFT_PACKAGE
import Atomics
import Deferred
#elseif COCOAPODS
import Atomics
#elseif XCODE && !FORCE_PLAYGROUND_COMPATIBILITY
import Deferred.Atomics
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
/// A progress object whose attributes reflect that of an external progress
/// tree.
private final class ProxyProgress: Progress {

    @objc dynamic let observee: Progress
    lazy var token = Observation(forUpdating: self)

    init(attachingTo observee: Progress) {
        self.observee = observee
        super.init(parent: nil)
        totalUnitCount = 100
        token.activate(observing: observee)
    }

    deinit {
        token.invalidate(observing: observee)
    }

    // MARK: - Derived values

    override func cancel() {
        observee.cancel()
    }

    override func pause() {
        observee.pause()
    }

    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    override func resume() {
        observee.resume()
    }

    @objc static let keyPathsForValuesAffectingUserInfo: Set<String> = [
        #keyPath(observee.userInfo)
    ]

    override var userInfo: [ProgressUserInfoKey: Any] {
        return observee.userInfo
    }

    override func setUserInfoObject(_ objectOrNil: Any?, forKey key: ProgressUserInfoKey) {
        observee.setUserInfoObject(objectOrNil, forKey: key)
    }

    // MARK: - KVO babysitting

    func inheritFraction() {
        completedUnitCount = observee.isIndeterminate ? -1 : Int64(observee.fractionCompleted * Double(totalUnitCount))
    }

    func inheritAttribute(_ value: Any?, forKeyPath keyPath: String) {
        setValue(value, forKeyPath: keyPath)
    }

    func inheritCancelled() {
        if observee.isCancelled {
            super.cancel()
        }
    }

    func inheritPaused() {
        if observee.isPaused {
            super.pause()
        } else {
            super.resume()
        }
    }

    /// A side-table object to weakify the progress observer and prevent
    /// delivery of notifications after deinit.
    final class Observation: NSObject {
        static var fractionContext = false
        static var attributesContext = false
        static var cancelledContext = false
        static var pausedContext = false

        static let fractionKeyPaths = [
            #keyPath(Progress.fractionCompleted),
            #keyPath(Progress.isIndeterminate)
        ]

        static let attributesKeyPaths = [
            #keyPath(Progress.localizedDescription),
            #keyPath(Progress.localizedAdditionalDescription),
            #keyPath(Progress.cancellable),
            #keyPath(Progress.pausable),
            #keyPath(Progress.kind)
        ]

        struct State: OptionSet {
            let rawValue: UInt8
            static let ready = State(rawValue: 1 << 0)
            static let observing = State(rawValue: 1 << 1)
            static let cancellable: State = [.ready, .observing]
            static let cancelled = State(rawValue: 1 << 2)
        }

        var state = UInt8() // see State
        weak var observer: ProxyProgress?

        init(forUpdating observer: ProxyProgress) {
            self.observer = observer
            bnr_atomic_init(&state, State.ready.rawValue)
            super.init()
        }

        func activate(observing observee: Progress) {
            for key in Observation.fractionKeyPaths {
                observee.addObserver(self, forKeyPath: key, options: .initial, context: &Observation.fractionContext)
            }

            for key in Observation.attributesKeyPaths {
                observee.addObserver(self, forKeyPath: key, options: [ .initial, .new ], context: &Observation.attributesContext)
            }
            observee.addObserver(self, forKeyPath: #keyPath(Progress.cancelled), options: .initial, context: &Observation.cancelledContext)
            observee.addObserver(self, forKeyPath: #keyPath(Progress.paused), options: .initial, context: &Observation.pausedContext)

            bnr_atomic_fetch_or(&state, State.observing.rawValue, .release)
        }

        func invalidate(observing observee: Progress) {
            let oldState = State(rawValue: bnr_atomic_fetch_and(&state, ~State.ready.rawValue, .relaxed))
            guard !oldState.isStrictSuperset(of: .cancellable) else { return }
            bnr_atomic_fetch_or(&state, State.cancelled.rawValue, .relaxed)

            for key in Observation.fractionKeyPaths {
                observee.removeObserver(self, forKeyPath: key, context: &Observation.fractionContext)
            }

            for key in Observation.attributesKeyPaths {
                observee.removeObserver(self, forKeyPath: key, context: &Observation.attributesContext)
            }
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.cancelled), context: &Observation.cancelledContext)
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.paused), context: &Observation.pausedContext)
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            let state = State(rawValue: bnr_atomic_load(&self.state, .relaxed))
            guard state.contains(.ready), let observer = observer else { return }
            // This would be prettier as a switch.
            // https://bugs.swift.org/browse/SR-7877
            if context == &Observation.fractionContext {
                observer.inheritFraction()
            } else if context == &Observation.attributesContext, let keyPath = keyPath {
                observer.inheritAttribute(change?[.newKey], forKeyPath: keyPath)
            } else if context == &Observation.cancelledContext {
                observer.inheritCancelled()
            } else if context == &Observation.pausedContext {
                observer.inheritPaused()
            }
        }
    }
}

extension Progress {
    /// Emulate `addChild(_:withPendingUnitCount:)` if `progress` may possibly
    /// already have a parent.
    func adoptChild(_ progress: Progress, pendingUnitCount: Int64) {
        let child = ProxyProgress(attachingTo: progress)
        addChild(child, withPendingUnitCount: pendingUnitCount)
    }
}

// MARK: - Convenience initializers

extension Progress {
    /// Indeterminate progress which will likely not change.
    static func indefinite() -> Progress {
        let progress = Progress(totalUnitCount: -1)
        progress.isCancellable = false
        return progress
    }

    /// Progress for which no work actually needs to be done.
    static func noWork() -> Progress {
        let progress = Progress(totalUnitCount: 0)
        progress.completedUnitCount = 1
        progress.isCancellable = false
        progress.isPausable = false
        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    static func wrappingCompletion<Wrapped: FutureProtocol>(of wrapped: Wrapped, uponCancel cancellation: (() -> Void)?) -> Progress {
        let totalUnitCount: Int64 = wrapped.peek() != nil ? 0 : -1
        let progress = Progress(totalUnitCount: totalUnitCount)

        if let cancellation = cancellation {
            progress.cancellationHandler = cancellation
        } else {
            progress.isCancellable = false
        }

        wrapped.upon(.global(qos: .utility)) { _ in
            progress.totalUnitCount = 1
            progress.completedUnitCount = 1
        }

        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    static func wrappingSuccess<Wrapped: TaskProtocol>(of wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil) -> Progress {
        switch (wrapped as? Task<Wrapped.SuccessValue>, cancellation) {
        case (let task?, nil):
            return task.progress
        case (let task?, let cancellation?):
            let progress = Progress(totalUnitCount: 1)
            progress.cancellationHandler = cancellation
            progress.adoptChild(task.progress, pendingUnitCount: 1)
            return progress
        default:
            return .wrappingCompletion(of: wrapped, uponCancel: cancellation)
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
            outer.addChild(inner, withPendingUnitCount: taskRootUnitCount)
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
            outer.adoptChild(inner, pendingUnitCount: taskRootUnitCount)
            return outer
        }
    }
}

#endif
