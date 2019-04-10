//
//  TaskChain.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/12/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation

/// Describes the relationships implied by the order of calls to `Task`
/// initializers or Task-based `map` and `andThen` that form an implicit tree of
/// `Progress` objects.
///
/// Instances of this type are created as helpers while initializing a `Task`
/// and while performing `Task` chaining.
struct TaskChain {
    /// The default work unit count for a single call to a `Task` initializer or
    /// chaining method.
    private static let singleUnit = Int64(1)
    /// The work unit count applied when a chaining method may later determine
    /// a higher or lower unit count.
    private static let undeterminedUnit = Int64(8)
    /// The work unit count when a `Task` initializer or chaining method accepts
    /// an user-provided `Progress` instance.
    private static let explicitChildUnitCount = Int64(20)

    /// Marker class representing the start of a task chain.
    ///
    /// The root is formed by the first call to initialize `Task` in a chain.
    /// Subsequent `Task`s created in the course of `map` or `flatMap` re-use
    /// that first task's `Root`.
    @objc(BNRTaskRootProgress)
    private class Root: Progress {
        /// Key for value of type `[Root]?` in `Thread.threadDictionary`.
        static let threadKey = "_BNRTaskProgressStack"

        /// Propogates the current Task chain for explicit composition during
        /// `Task.andThen`.
        static var activeStack: [Root] {
            get {
                return Thread.current.threadDictionary[threadKey] as? [Root] ?? []
            }
            set {
                Thread.current.threadDictionary[threadKey] = newValue
            }
        }

        /// Key for value of type `Bool` in `Progress.userInfo`.
        static let expandsKey = ProgressUserInfoKey(rawValue: "_BNRTaskExpandChildren")

        /// If `true`,  Propogates the current Task chain for explicit composition during
        /// `Task.andThen`.
        var expandsAddedChildren: Bool {
            get {
                return userInfo[Root.expandsKey] as? Bool == true
            }
            set {
                setUserInfoObject(newValue, forKey: Root.expandsKey)
            }
        }

        @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
        override func addChild(_ child: Progress, withPendingUnitCount unitCount: Int64) {
            if expandsAddedChildren, !child.wasGeneratedByTask {
                totalUnitCount += TaskChain.explicitChildUnitCount - unitCount
                super.addChild(child, withPendingUnitCount: TaskChain.explicitChildUnitCount)
            } else {
                super.addChild(child, withPendingUnitCount: unitCount)
            }
        }
    }

    /// The beginning of this chain. May be the same as `effectiveProgress`.
    private let root: Root

    /// The progress object to be used to represent this entire chain.
    ///
    /// This may not be the user-defined progress passed-in; that may become
    /// a child of this progress.
    let effectiveProgress: Progress

    /// Locates or creates the root of a task chain, then generates any
    /// progress objects needed to represent `wrapped` in that chain.
    init<Wrapped: TaskProtocol>(startingWith wrapped: Wrapped, using customProgress: Progress? = nil, uponCancel cancellation: (() -> Void)? = nil) {
        if let root = Root.activeStack.last {
            // We're inside `andThen` — `commitAndThen(with:)` will compose instead.
            self.root = root
            self.effectiveProgress = customProgress ?? .basicProgress(parent: nil, for: wrapped, uponCancel: cancellation)
        } else if let root = customProgress as? Root {
            // Being passed the `progress` of another `Task`. Just pass it through.
            self.root = root
            self.effectiveProgress = root
        } else {
            // Create a "root" progress for the task and its follow-up steps. If
            // the initial operation provides progress, give it a larger slice.
            let unitCount = customProgress == nil ? TaskChain.singleUnit : TaskChain.explicitChildUnitCount
            self.root = Root()
            self.root.totalUnitCount = unitCount
            self.effectiveProgress = root

            if let customProgress = customProgress, cancellation == nil {
                root.adoptChild(customProgress, withPendingUnitCount: unitCount)
            } else {
                root.monitorCompletion(of: wrapped, uponCancel: cancellation, withPendingUnitCount: unitCount)
            }
        }
    }

    /// Locates or creates the root of a task chain, then increments its
    /// total units in preparation for a follow-up operation to be performed.
    private init<Wrapped: TaskProtocol>(continuingFrom wrapped: Wrapped, pendingUnitCount: Int64) {
        if let task = wrapped as? Task<Wrapped.Success>, let root = task.progress as? Root {
            // If `wrapped` is a Task created normally, reuse the progress root;
            // this `map` or `andThen` builds on that progress.
            root.totalUnitCount += pendingUnitCount
            self.root = root
            self.effectiveProgress = root
        } else {
            // If `wrapped` is a `Future` or something else, start a new chain.
            self.root = Root()
            self.root.totalUnitCount = TaskChain.singleUnit + pendingUnitCount
            self.effectiveProgress = root

            root.monitorCompletion(of: wrapped, withPendingUnitCount: TaskChain.singleUnit)
        }
    }

    // MARK: -

    /// Locates or creates the root of a task chain, then increments its
    /// total units in preparation for a follow-up operation to be performed.
    init<Wrapped: TaskProtocol>(mapFrom wrapped: Wrapped) {
        self.init(continuingFrom: wrapped, pendingUnitCount: TaskChain.singleUnit)
    }

    /// The handler passed to `map` can use implicit progress reporting.
    /// During the handler, the first `Progress` object created using
    /// `parent: .current()` will be given a larger slice of the task chain on
    /// macOS 10.11, iOS 9, and above.
    func beginMap() {
        root.expandsAddedChildren = true
        root.becomeCurrent(withPendingUnitCount: TaskChain.singleUnit)
    }

    /// See `beginMap`.
    func commitMap() {
        root.resignCurrent()
        root.expandsAddedChildren = false
    }

    // MARK: -

    /// Locates or creates the root of a task chain, then increments its
    /// total units in preparation for a follow-up operation to be performed.
    init<Wrapped: TaskProtocol>(andThenFrom wrapped: Wrapped) {
        self.init(continuingFrom: wrapped, pendingUnitCount: TaskChain.undeterminedUnit)
    }

    /// The handler passed to `andThen` uses explicit progress reporting.
    /// After returning a from the handler, locate or create a representative
    /// progress and attach it to the root. If this next step provides custom
    /// progress, give it a larger slice.
    func beginAndThen() {
        Root.activeStack.append(root)
    }

    /// See `beginAndThen`.
    func commitAndThen<Wrapped: TaskProtocol>(with wrapped: Wrapped) {
        let wrappedProgress = (wrapped as? Task<Wrapped.Success>)?.progress
        let pendingUnitCount = wrappedProgress?.wasGeneratedByTask == false ? TaskChain.explicitChildUnitCount : TaskChain.singleUnit
        root.totalUnitCount += pendingUnitCount - TaskChain.undeterminedUnit
        if let wrappedProgress = wrappedProgress {
            root.monitorChild(wrappedProgress, withPendingUnitCount: pendingUnitCount)
        } else {
            root.monitorCompletion(of: wrapped, uponCancel: wrapped.cancel, withPendingUnitCount: pendingUnitCount)
        }
        Root.activeStack.removeLast()
    }

    /// When the `andThen` handler can't be run at all, mark the enqueued unit
    /// as complete anyway.
    func flushAndThen() {
        root.becomeCurrent(withPendingUnitCount: TaskChain.singleUnit)
        root.resignCurrent()
        root.totalUnitCount += TaskChain.singleUnit - TaskChain.undeterminedUnit
        Root.activeStack.removeLast()
    }
}
#endif
