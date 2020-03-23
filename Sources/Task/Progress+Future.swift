//
//  Progress+Future.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/12/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#if SWIFT_PACKAGE
import Deferred
#endif

private final class ProgressCompletionExecutor: Executor {

    static let shared = ProgressCompletionExecutor()

    func submit(_ body: @escaping () -> Void) {
        body()
    }

}

extension Progress {
    private static let didTaskGenerateKey = ProgressUserInfoKey("_BNRTaskIsGenerated")

    /// Returns a progress that is indeterminate until `wrapped` is fulfilled,
    /// then finishes at 100%.
    static func basicProgress<Wrapped: FutureProtocol>(for wrapped: Wrapped, uponCancel cancellation: (() -> Void)?) -> Progress {
        let child = Progress(parent: nil, userInfo: [
            Progress.didTaskGenerateKey: true
        ])

        if wrapped.peek() != nil {
            // No work to be done; already finished.
            child.completedUnitCount = 1
        } else {
            // Start as indeterminate.
            child.completedUnitCount = -1

            // Become determinate and completed upon fill.
            wrapped.upon(ProgressCompletionExecutor.shared) { _ in
                child.completedUnitCount = 1
            }
        }

        child.cancellationHandler = cancellation
        child.isCancellable = cancellation != nil
        return child
    }

    /// `true` for wrappers created by `Progress.basicProgress(for:uponCancel:)`.
    var wasGeneratedByTask: Bool {
        return userInfo[Progress.didTaskGenerateKey] as? Bool == true
    }

    /// Synthesizes a simple progress object based on the fulfillment of
    /// `wrapped`. If the future is not already fulfilled, the
    /// `pendingUnitCount` of `self` is assigned upon fulfillment. Otherwise,
    /// the `pendingUnitCount` becomes complete immediately.
    func monitorCompletion<Wrapped: FutureProtocol>(of wrapped: Wrapped, uponCancel cancellation: (() -> Void)? = nil, withPendingUnitCount pendingUnitCount: Int64) {
        let child = Progress.basicProgress(for: wrapped, uponCancel: cancellation)
        addChild(child, withPendingUnitCount: pendingUnitCount)
    }
}
#endif
