//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

import Dispatch
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

private struct AllFilled<SuccessValue>: TaskProtocol {
    let group = DispatchGroup()
    let combined = Deferred<Task<SuccessValue>.Result>()
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    let progress = Progress(parent: nil, userInfo: nil)
    #else
    let cancellations: [() -> Void]
    #endif

    init<Base: Collection>(_ base: Base, mappingBy transform: @escaping([Base.Element]) -> SuccessValue) where Base.Element: TaskProtocol {
        let array = Array(base)
        let queue = DispatchQueue.global(qos: .utility)

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        progress.totalUnitCount = numericCast(array.count)
        #else
        self.cancellations = array.map { $0.cancel }
        #endif

        for future in array {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if let task = future as? Task<Base.Element.SuccessValue> {
                progress.adoptChild(task.progress, pendingUnitCount: 1)
            } else {
                progress.addChild(.wrappingSuccess(of: future), withPendingUnitCount: 1)
            }
            #endif

            group.enter()
            future.upon(queue) { [combined, group] (result) in
                result.withValues(ifLeft: { (error) in
                    _ = combined.fail(with: error)
                }, ifRight: { _ in })

                group.leave()
            }
        }

        group.notify(queue: queue) { [combined] in
            combined.succeed(with: transform(array))
        }
    }

    func upon(_ executor: Executor, execute body: @escaping(Task<SuccessValue>.Result) -> Void) {
        combined.upon(executor, execute: body)
    }

    func peek() -> Task<SuccessValue>.Result? {
        return combined.peek()
    }

    func wait(until time: DispatchTime) -> Task<SuccessValue>.Result? {
        return combined.wait(until: time)
    }

    #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
    func cancel() {
        for cancellation in cancellations {
            cancellation()
        }
    }
    #endif
}

extension Collection where Element: TaskProtocol {
    /// Compose a number of tasks into a single array.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be fulfilled by combining the values.
    public func allSucceeded() -> Task<[Element.SuccessValue]> {
        guard !isEmpty else {
            return Task(success: [])
        }

        let wrapper = AllFilled(self) { (array) -> [Element.SuccessValue] in
            // Expect each to be filled but not successful right now.
            // swiftlint:disable:next force_unwrapping
            return array.compactMap { try? $0.peek()!.extract() }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(wrapper, progress: wrapper.progress)
        #else
        return Task(wrapper, uponCancel: wrapper.cancel)
        #endif
    }
}

extension Collection where Element: TaskProtocol, Element.SuccessValue == Void {
    /// Compose a number of tasks into a single array.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public func allSucceeded() -> Task<Void> {
        guard !isEmpty else {
            return Task(success: ())
        }

        let wrapper = AllFilled(self) { _ in () }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(wrapper, progress: wrapper.progress)
        #else
        return Task(wrapper, uponCancel: wrapper.cancel)
        #endif
    }
}
