//
//  Progress+ExplicitComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/12/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation

/// A progress object whose attributes reflect that of an external progress
/// tree.
@objc(BNRTaskProxyProgress)
private final class ProxyProgress: Progress {

    @objc dynamic let observee: Progress
    let token = Observation()

    /// Creates the progress observer for reflecting the state of `observee`.
    ///
    /// Given a `parent` of `Progress.current()`, attach the proxy for implicit
    /// composition.
    init(parent: Progress?, referencing observee: Progress) {
        self.observee = observee
        super.init(parent: parent)
        // The units for this type are percents.
        totalUnitCount = 1000
        token.observer = self
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

    func inheritAttribute(forKeyPath keyPath: String) {
        setValue(observee.value(forKeyPath: keyPath), forKeyPath: keyPath)
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
        static let allKeyPaths = [
            #keyPath(Progress.fractionCompleted),
            #keyPath(Progress.isIndeterminate),
            #keyPath(Progress.localizedDescription),
            #keyPath(Progress.localizedAdditionalDescription),
            #keyPath(Progress.cancellable),
            #keyPath(Progress.pausable),
            #keyPath(Progress.kind),
            #keyPath(Progress.cancelled),
            #keyPath(Progress.paused)
        ]

        weak var observer: ProxyProgress?

        func activate(observing observee: Progress) {
            objc_setAssociatedObject(observee, Unmanaged.passUnretained(self).toOpaque(), self, .OBJC_ASSOCIATION_RETAIN)

            for key in Observation.allKeyPaths {
                observee.addObserver(self, forKeyPath: key, options: .initial, context: nil)
            }
        }

        func invalidate(observing observee: Progress) {
            for key in Observation.allKeyPaths {
                observee.removeObserver(self, forKeyPath: key, context: nil)
            }

            objc_setAssociatedObject(observee, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_ASSIGN)
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard let keyPath = keyPath, let observer = observer else { return }
            switch keyPath {
            case #keyPath(Progress.fractionCompleted), #keyPath(Progress.isIndeterminate):
                observer.inheritFraction()
            case #keyPath(Progress.isCancelled):
                observer.inheritCancelled()
            case #keyPath(Progress.isPaused):
                observer.inheritPaused()
            default:
                observer.inheritAttribute(forKeyPath: keyPath)
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
