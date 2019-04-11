//
//  Progress+ExplicitComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/12/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#elseif XCODE && !FORCE_PLAYGROUND_COMPATIBILITY
import Deferred.Atomics
#endif

/// A progress object whose attributes reflect that of an external progress
/// tree.
@objc(BNRTaskProxyProgress)
private final class ProxyProgress: Progress {

    @objc dynamic let observee: Progress
    lazy var token = Observation(forUpdating: self)

    /// Creates the progress observer for reflecting the state of `observee`.
    ///
    /// Given a `parent` of `Progress.current()`, attach the proxy for implicit
    /// composition.
    init(parent: Progress?, referencing observee: Progress) {
        self.observee = observee
        super.init(parent: parent)
        // The units for this type are percents.
        totalUnitCount = 1000
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
        // Mirror `isIndeterminate`, otherwise reflect the percent to 1 decimal.
        completedUnitCount = observee.isIndeterminate ? -1 : Int64(observee.fractionCompleted * 1000)
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
        } else if #available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *) {
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
    /// Add a progress object as a child of a progress tree. The
    /// `pendingUnitCount` indicates the expected work for the progress unit.
    ///
    /// This method is a shim for `Progress.addChild(_:withPendingUnitCount:)`,
    /// using an approximation of the behavior on iOS 8 and macOS 10.10.
    func adoptChild(_ child: Progress, withPendingUnitCount pendingUnitCount: Int64) {
        if #available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *) {
            addChild(child, withPendingUnitCount: pendingUnitCount)
        } else {
            monitorChild(child, withPendingUnitCount: pendingUnitCount)
        }
    }

    /// Adds an external progress tree as a child of this progress tree.
    ///
    /// This method has a similar effect to
    /// `Progress.addChild(_:withPendingUnitCount:)`, where `pendingUnitCount`
    /// becomes represented by whatever units `child` represents.
    ///
    /// This method may be useful if `child` cannot be known to already have no
    /// parent.
    func monitorChild(_ child: Progress, withPendingUnitCount pendingUnitCount: Int64) {
        if #available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *) {
            let child = ProxyProgress(parent: nil, referencing: child)
            addChild(child, withPendingUnitCount: pendingUnitCount)
        } else {
            becomeCurrent(withPendingUnitCount: pendingUnitCount)
            _ = ProxyProgress(parent: self, referencing: child)
            resignCurrent()
        }
    }
}
#endif
